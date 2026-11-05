#!/usr/bin/env bash
# Deploys this repo into a throwaway HOME and checks what a Linux server relies on.
# Needs chezmoi, git and zsh. Everything stays inside the temporary HOME.

set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

HOME="$(mktemp -d)"
export HOME
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
cd "$HOME"

fail() {
  echo "::error::$1"
  exit 1
}

# `zsh -ic` runs without a terminal here, which makes zsh print this one notice
zsh_stderr() {
  { zsh -ic "$1" 2>&1 >/dev/null </dev/null || true; } | grep -v "can't change option: zle" || true
}

echo "--- deploy"
chezmoi --source "$root" init --apply </dev/null

echo "--- second apply stays quiet"
output="$(chezmoi apply </dev/null 2>&1)"
[ -z "$output" ] || fail "second apply is not quiet: $output"

echo "--- macOS-only files stay away"
for path in Library .config/ghostty .config/zed .config/nvim .config/asdf .tool-versions \
  .local/bin/idea .local/bin/update-brew .local/bin/sync-withings-garmin.sh; do
  [ ! -e "$HOME/$path" ] || fail "macOS-only path deployed: $path"
done

echo "--- prezto"
[ -d "$HOME/.config/zsh/.zprezto" ] || fail "prezto is not installed"

echo "--- new shell prints no errors"
errors="$(zsh_stderr true)"
[ -z "$errors" ] || fail "new shell prints errors: $errors"

echo "--- everyday commands work without the macOS tools"
zsh -ic 'ls /' >/dev/null 2>&1 </dev/null || fail "ls is broken"

echo "--- ~/.local/bin can't shadow system tools, but stays reachable"
printf '#!/bin/sh\necho planted\n' > "$HOME/.local/bin/ls"
printf '#!/bin/sh\necho mine\n' > "$HOME/.local/bin/mytool"
chmod +x "$HOME/.local/bin/ls" "$HOME/.local/bin/mytool"
resolved="$(zsh -ic 'whence -p ls' 2>/dev/null </dev/null | tail -n 1)"
[ "$resolved" != "$HOME/.local/bin/ls" ] || fail "~/.local/bin shadows ls"
resolved="$(zsh -ic 'whence -p mytool' 2>/dev/null </dev/null | tail -n 1)"
[ "$resolved" = "$HOME/.local/bin/mytool" ] || fail "~/.local/bin is not on PATH"

echo "--- git commit works without a YubiKey"
repo="$(mktemp -d)"
git -C "$repo" init -q -b main
git -C "$repo" commit -q --allow-empty -m init || fail "git commit fails"

echo "--- gcleanlocal keeps main and develop, deletes merged branches"
git -C "$repo" branch develop
git -C "$repo" branch merged-topic
git -C "$repo" switch -q -c feature
git -C "$repo" commit -q --allow-empty -m work
(cd "$repo" && zsh -ic gcleanlocal >/dev/null 2>&1 </dev/null) || true
branches="$(git -C "$repo" branch --format='%(refname:short)' | sort | tr '\n' ' ')"
[ "$branches" = "develop feature main " ] || fail "gcleanlocal left: $branches"

echo "All checks passed"
