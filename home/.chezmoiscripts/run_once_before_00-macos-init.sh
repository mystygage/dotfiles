#!/usr/bin/env bash

set -euo pipefail

if [ "${CHEZMOI_OS}" == "darwin" ]; then

  # Ask for the administrator password upfront
  sudo -v

  # Keep-alive: update existing `sudo` time stamp until this script has finished
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

  # XDG Cache folder
  # ~/Library/Caches directory is excluded from Time Machine by default.
  XDG_CACHE_FOLDER="${HOME}/Library/Caches/XDG-cache"
  HOME_CACHE_FOLDER="${HOME}/.cache"
  if [ ! -L "${HOME_CACHE_FOLDER}" ] ; then
    mkdir -p "${HOME_CACHE_FOLDER}"
    mv "${HOME_CACHE_FOLDER}" "${XDG_CACHE_FOLDER}"
    ln -s "${XDG_CACHE_FOLDER}" "${HOME_CACHE_FOLDER}"
  fi

  # Script is borrowed from https://github.com/MikeMcQuaid/strap

  # Check and, if necessary, enable sudo authentication using TouchID.
  # Don't care about non-alphanumeric filenames when doing a specific match
  if ls /usr/lib/pam | grep -q "pam_tid.so"; then
    echo "Configuring sudo authentication using TouchID:"
    PAM_FILE="/etc/pam.d/sudo"
    FIRST_LINE="# sudo: auth account password session"
    if grep -q pam_tid.so "$PAM_FILE"; then
      echo "Ok"
    elif ! head -n1 "$PAM_FILE" | grep -q "$FIRST_LINE"; then
      echo "$PAM_FILE is not in the expected format!"
    else
      TOUCHID_LINE="auth       sufficient     pam_tid.so"
      sudo sed -i .bak -e \
        "s/$FIRST_LINE/$FIRST_LINE\n$TOUCHID_LINE/" \
        "$PAM_FILE"
      sudo rm "$PAM_FILE.bak"
      echo "Ok"
    fi
  fi

  # Install the Xcode Command Line Tools.
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    echo "Installing the Xcode Command Line Tools:"
    CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    sudo touch "$CLT_PLACEHOLDER"

    CLT_PACKAGE=$(softwareupdate -l \
      | grep -B 1 "Command Line Tools" \
      | awk -F"*" '/^ *\*/ {print $2}' \
      | sed -e 's/^ *Label: //' -e 's/^ *//' \
      | sort -V \
      | tail -n1)
    sudo softwareupdate -i "$CLT_PACKAGE"
    sudo rm -f "$CLT_PLACEHOLDER"
    if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
      echo "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
    fi
  fi


  # Check if the Xcode license is agreed to and agree if not.
  xcode_license() {
    if /usr/bin/xcrun clang 2>&1 | grep -q license; then
      echo "Asking for Xcode license confirmation:"
      sudo xcodebuild -license
    fi
  }
  xcode_license

  # Setup Homebrew directory and permissions.
  echo "Installing Homebrew:"
  HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
  if [ -z "$HOMEBREW_PREFIX" ] || [ -z "$HOMEBREW_REPOSITORY" ]; then
    UNAME_MACHINE="$(/usr/bin/uname -m)"
    if [[ $UNAME_MACHINE == "arm64" ]]; then
      HOMEBREW_PREFIX="/opt/homebrew"
      HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
    else
      HOMEBREW_PREFIX="/usr/local"
      HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
    fi
  fi
  [ -d "$HOMEBREW_PREFIX" ] || sudo mkdir -p "$HOMEBREW_PREFIX"
  if [ "$HOMEBREW_PREFIX" = "/usr/local" ]; then
    sudo chown "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
  fi
  (
    cd "$HOMEBREW_PREFIX"
    sudo mkdir -p Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    sudo chown "$USER:admin" Cellar Caskroom Frameworks bin etc include lib opt sbin share var
  )

  [ -d "$HOMEBREW_REPOSITORY" ] || sudo mkdir -p "$HOMEBREW_REPOSITORY"
  sudo chown -R "$USER:admin" "$HOMEBREW_REPOSITORY"

  if [ $HOMEBREW_PREFIX != $HOMEBREW_REPOSITORY ]; then
    ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
  fi

  # Download Homebrew.
  export GIT_DIR="$HOMEBREW_REPOSITORY/.git" GIT_WORK_TREE="$HOMEBREW_REPOSITORY"
  git init -q
  git config remote.origin.url "https://github.com/Homebrew/brew"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch -q --tags --force
  git reset -q --hard origin/master
  unset GIT_DIR GIT_WORK_TREE
  echo "Ok"


  # Update Homebrew.
  export PATH="$HOMEBREW_PREFIX/bin:$PATH"
  echo "Updating Homebrew:"
  brew update --quiet
  echo "Ok"

  if [ "${CHEZMOI_ARCH}" == "arm64" ]; then
    echo "Install Rosetta 2"
    sudo softwareupdate --install-rosetta --agree-to-license

    # Check and install any remaining software updates.
    echo "Checking for software updates:"
    if softwareupdate -l 2>&1 | grep -q "No new software available."; then
      echo "Ok"
    else
      echo "Installing software updates:"
      sudo softwareupdate --install --all
      xcode_license
      echo "Ok"
    fi
  fi

fi
