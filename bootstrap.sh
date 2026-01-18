#!/bin/sh
set -eu

REPO="https://github.com/mystygage/dotfiles.git"

log() {
  printf "\n==> %s\n" "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

OS="$(uname -s)"
ARCH="$(uname -m)"

###############################################################################
# macOS (Apple Silicon)
###############################################################################
bootstrap_macos() {
  log "Detected macOS ($ARCH)"

  if [ "$ARCH" != "arm64" ]; then
    echo "This script supports Apple Silicon macOS only."
    exit 1
  fi

  # Xcode Command Line Tools
  if ! xcode-select -p >/dev/null 2>&1; then
    log "Installing Xcode Command Line Tools"
    xcode-select --install
    echo "Please finish the Xcode installation, then re-run this script."
    exit 0
  fi

  # Homebrew
  if ! command_exists brew; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Ensure brew is available in this shell
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  # Git
  if ! command_exists git; then
    log "Installing git"
    brew install git
  fi

  # Chezmoi
  if ! command_exists chezmoi; then
    log "Installing chezmoi"
    brew install chezmoi
  fi
}

###############################################################################
# Linux
###############################################################################
bootstrap_linux() {
  log "Detected Linux"

  if command_exists apt-get; then
    PKG_MANAGER="apt"
  elif command_exists dnf; then
    PKG_MANAGER="dnf"
  else
    echo "Unsupported Linux distribution (apt or dnf required)."
    exit 1
  fi

  # Git
  if ! command_exists git; then
    log "Installing git"
    if [ "$PKG_MANAGER" = "apt" ]; then
      sudo apt-get update
      sudo apt-get install -y git
    else
      sudo dnf install -y git
    fi
  fi

  # Chezmoi
  if ! command_exists chezmoi; then
    log "Installing chezmoi"
    sh -c "$(curl -fsLS get.chezmoi.io)"
  fi
}

###############################################################################
# Main
###############################################################################
case "$OS" in
  Darwin)
    bootstrap_macos
    ;;
  Linux)
    bootstrap_linux
    ;;
  *)
    echo "Unsupported operating system: $OS"
    exit 1
    ;;
esac

###############################################################################
# Initialize chezmoi
###############################################################################
CHEZMOI_DIR="$HOME/.local/share/chezmoi"

if [ ! -d "$CHEZMOI_DIR" ]; then
  log "Initializing chezmoi"
  log "chezmoi init --apply "$REPO""
else
  log "Chezmoi already initialized, applying changes"
  log "chezmoi apply"
fi

log "Bootstrap complete"
