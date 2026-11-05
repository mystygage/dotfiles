#!/usr/bin/env bash
# Installs a pinned chezmoi and verifies it against the published checksum.

set -euo pipefail

version="2.74.0"
case "$(uname -m)" in
  x86_64)
    arch="amd64"
    sha256="1b98a567f726f41540414aea4caf912699d53e248b29ccf8369cf553657b2374"
    ;;
  aarch64 | arm64)
    arch="arm64"
    sha256="bf89495d1aab5e4fa0fc1ba9457837b34ee8dec9b787570f2de3e1c12a5835a5"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/chezmoi.tar.gz" \
  "https://github.com/twpayne/chezmoi/releases/download/v${version}/chezmoi_${version}_linux_${arch}.tar.gz"
echo "$sha256  $tmp/chezmoi.tar.gz" | sha256sum --check --quiet -
sudo tar -xzf "$tmp/chezmoi.tar.gz" -C /usr/local/bin chezmoi
chezmoi --version
