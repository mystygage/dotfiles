#!/usr/bin/env bash
# Deploys this repo into a throwaway HOME and checks what a Linux server relies on.
# Needs chezmoi, git and zsh. Everything stays inside the temporary HOME.

set -euo pipefail

root="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"

HOME="$(mktemp -d)"
export HOME
export TERM=xterm-256color
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ZDOTDIR
cd "$HOME"

fail() {
  echo "::error::$1"
  exit 1
}

# CI has no terminal and an interactive zsh complains about that, so give it a pseudo-terminal
zsh_stderr() {
  local errors
  errors="$(mktemp)"
  script -qec "zsh -ic '$1' 2>'$errors'" /dev/null >/dev/null </dev/null || true
  cat "$errors"
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

echo "--- prezto and powerlevel10k at their pins"
prezto="$HOME/.config/zsh/.zprezto"
pin="$(sed -n '/^\[pins\.prezto\]/,/^\[/s/^  ref = "\(.*\)"/\1/p' "$root/home/.chezmoidata.toml")"
[ -d "$prezto" ] || fail "prezto is not installed"
[ "$(git -C "$prezto" rev-parse HEAD)" = "$pin" ] || fail "prezto is not at $pin"
[ -r "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme" ] || fail "powerlevel10k is not deployed"
loaded="$(zsh -ic 'print $+functions[p10k]' 2>/dev/null </dev/null | tail -n 1)"
[ "$loaded" = 1 ] || fail "powerlevel10k does not load"

echo "--- an existing prezto clone moves to the pin, unless it has local edits"
git -C "$prezto" -c advice.detachedHead=false checkout -q HEAD~1
git -C "$prezto/modules/prompt/external/powerlevel10k" -c advice.detachedHead=false checkout -q HEAD~1
chezmoi state delete-bucket --bucket=entryState
chezmoi apply </dev/null
[ "$(git -C "$prezto" rev-parse HEAD)" = "$pin" ] || fail "existing prezto clone stays off $pin"
[ -z "$(git -C "$prezto" status --porcelain)" ] || fail "prezto submodules are not reset"
echo "# local edit" >> "$prezto/init.zsh"
chezmoi state delete-bucket --bucket=entryState
if chezmoi apply </dev/null 2>/dev/null; then
  fail "apply moves prezto over local edits"
fi
git -C "$prezto" checkout -q -- init.zsh
chezmoi apply </dev/null

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
