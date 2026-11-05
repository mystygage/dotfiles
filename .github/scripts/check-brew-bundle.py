#!/usr/bin/env python3
"""Checks that every entry of the package scripts still exists upstream.

A cask that vanished from Homebrew aborts `brew bundle`, and with it the whole
first apply on a new Mac. That can happen while nothing changes in this repo.
"""

import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

SCRIPTS = pathlib.Path(__file__).resolve().parents[2] / "home/.chezmoiscripts"
DEFAULT_FILES = [
    SCRIPTS / "run_onchange_before_install-brew-bundle.sh.tmpl",
    SCRIPTS / "run_onchange_before_install-mas-bundle.sh.tmpl",
]
ENTRY = re.compile(r'^(tap|brew|cask|mas) "([^"]+)"(?:, id: (\d+))?', re.MULTILINE)


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "dotfiles-ci"})
    return urllib.request.urlopen(request, timeout=120)


def index(kind, name_key, alias_keys):
    """Maps every current and former name to its Homebrew entry."""
    with get(f"https://formulae.brew.sh/api/{kind}.json") as response:
        entries = json.load(response)
    names = {}
    for entry in entries:
        for name in [entry[name_key]] + [n for key in alias_keys for n in entry.get(key) or []]:
            names[name] = entry
    return names


def tap_exists(name):
    user, repo = name.split("/")
    try:
        with get(f"https://github.com/{user}/homebrew-{repo}"):
            return True
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise


def app_exists(app_id):
    with get(f"https://itunes.apple.com/lookup?id={app_id}&country=de") as response:
        return json.load(response)["resultCount"] > 0


def main():
    files = [pathlib.Path(arg) for arg in sys.argv[1:]] or DEFAULT_FILES
    entries = [match for file in files for match in ENTRY.findall(file.read_text())]
    formulae = index("formula", "name", ["aliases", "oldnames"])
    casks = index("cask", "token", ["old_tokens"])

    failed = 0
    for kind, name, app_id in entries:
        if kind == "tap":
            if not tap_exists(name):
                print(f"::error::tap {name} no longer exists")
                failed += 1
        elif kind == "mas":
            # Only a warning: the lookup depends on the store region
            if not app_exists(app_id):
                print(f"::warning::App Store app {name} ({app_id}) not found")
        else:
            entry = (formulae if kind == "brew" else casks).get(name)
            if entry is None:
                print(f"::error::{kind} {name} no longer exists in Homebrew")
                failed += 1
            elif entry.get("disabled"):
                print(f"::error::{kind} {name} is disabled: {entry.get('disable_reason')}")
                failed += 1
            elif entry.get("deprecated"):
                print(f"::warning::{kind} {name} is deprecated: {entry.get('deprecation_reason')}")

    print(f"Checked {len(entries)} entries, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
