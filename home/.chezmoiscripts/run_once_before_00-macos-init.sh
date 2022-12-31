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

  # Check if the Xcode license is agreed to and agree if not.
  xcode_license() {
    if /usr/bin/xcrun clang 2>&1 | grep -q license; then
      echo "Asking for Xcode license confirmation:"
      sudo xcodebuild -license
    fi
  }
  xcode_license

  if [ "${CHEZMOI_ARCH}" == "arm64" ]; then
    echo "Install Rosetta 2"
    sudo softwareupdate --install-rosetta --agree-to-license
  fi

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
