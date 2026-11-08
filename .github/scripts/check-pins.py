#!/usr/bin/env python3
"""Reports pinned third-party code that has fallen behind upstream.

Commit pins live in home/.chezmoidata.toml, the Withings image digest in its
script. Being behind is a warning. It fails once upstream changes have waited
longer than MAX_LAG_DAYS, or when a pinned commit is no longer on upstream's
default branch (force push, or the repo moved).
"""

import datetime
import json
import os
import pathlib
import re
import sys
import tomllib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = ROOT / "home/.chezmoidata.toml"
WITHINGS = ROOT / "home/dot_local/bin/executable_sync-withings-garmin.sh"
IMAGE = re.compile(r'^IMAGE="ghcr\.io/([^@"]+)@(sha256:[0-9a-f]{64})"', re.MULTILINE)
MAX_LAG_DAYS = 30
NOW = datetime.datetime.now(datetime.timezone.utc)
MANIFEST_TYPES = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


def request(url, headers=None, method="GET"):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": "dotfiles-ci", **(headers or {})})
    return urllib.request.urlopen(req, timeout=60)


def github(path):
    headers = {"Accept": "application/vnd.github+json"}
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    with request(f"https://api.github.com/{path}", headers) as response:
        return json.load(response)


def days_since(timestamp):
    return (NOW - datetime.datetime.fromisoformat(timestamp)).days


def pins(table, prefix=""):
    """Yields (name, pin) for every table with repo and ref, nested ones too."""
    for key, value in table.items():
        if isinstance(value, dict):
            if "repo" in value and "ref" in value:
                yield prefix + key, value
            else:
                yield from pins(value, f"{prefix}{key}.")


def report(name, lag_days, message):
    """Prints a warning, or an error once the lag exceeds the limit. Returns 1 on error."""
    if lag_days > MAX_LAG_DAYS:
        print(f"::error::{name}: {message}, waiting for {lag_days} days (limit {MAX_LAG_DAYS})")
        return 1
    print(f"::warning::{name}: {message}")
    return 0


def check_commit(name, pin):
    repo = github(f"repos/{pin['repo']}")
    if repo["full_name"].lower() != pin["repo"].lower():
        print(f"::warning::{name}: {pin['repo']} moved to {repo['full_name']}")
    if repo["archived"]:
        print(f"::warning::{name}: {repo['full_name']} is archived")
    branch = repo["default_branch"]
    compare = github(f"repos/{pin['repo']}/compare/{pin['ref']}...{branch}")
    if compare["status"] == "identical":
        print(f"{name}: up to date with {branch}")
        return 0
    if compare["status"] != "ahead":
        print(f"::error::{name}: {pin['ref'][:7]} is not on {branch} ({compare['status']})")
        return 1
    oldest = compare["commits"][0]["commit"]["committer"]["date"]
    count = compare["ahead_by"]
    message = f"{count} new commit{'' if count == 1 else 's'} on {branch}, see {compare['html_url']}"
    return report(name, days_since(oldest), message)


def check_image(script):
    image, pinned = IMAGE.search(script.read_text()).groups()
    with request(f"https://ghcr.io/token?scope=repository:{image}:pull") as response:
        token = json.load(response)["token"]
    headers = {"Authorization": f"Bearer {token}", "Accept": MANIFEST_TYPES}
    with request(f"https://ghcr.io/v2/{image}/manifests/latest", headers, method="HEAD") as response:
        latest = response.headers["Docker-Content-Digest"]
    if latest == pinned:
        print(f"withings: up to date with {image}:latest")
        return 0
    # The image is built from the GitHub repo of the same name
    release = github(f"repos/{image}/releases/latest")
    message = f"{image}:latest is {release['tag_name']} ({latest}), see {release['html_url']}"
    return report("withings", days_since(release["published_at"]), message)


def main():
    data_file, withings = [pathlib.Path(arg) for arg in sys.argv[1:3]] or [DATA, WITHINGS]
    data = tomllib.loads(data_file.read_text())
    failed = sum(check_commit(name, pin) for name, pin in pins(data["pins"]))
    failed += check_image(withings)
    print(f"{failed} pins failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
