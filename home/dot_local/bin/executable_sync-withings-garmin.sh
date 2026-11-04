#!/usr/bin/env bash

set -euo pipefail

# OAuth tokens end up in DATA_DIR
umask 077

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/withings-sync"
USER_FILE="$DATA_DIR/.withings_user.json"
CONTAINER_NAME="withings"
# Third-party image that receives credentials: pinned, update the digest on purpose
IMAGE="ghcr.io/jaroslawhartman/withings-sync@sha256:f0faf4556bce22976f05fe00a692601ff07a20210770ad4afec7c508e55bb1f2"

# Defaults
FROMDATE=""
DO_CLEAN=false

# Argument-Parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      DO_CLEAN=true
      ;;
    --fromdate)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Error: --fromdate requires a value" >&2
        exit 1
      fi
      FROMDATE="$1"
      if [[ ! "$FROMDATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Error: --fromdate expects YYYY-MM-DD, got: $FROMDATE" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

for tool in docker op; do
  if ! command -v "$tool" >/dev/null; then
    echo "Error: $tool not found" >&2
    exit 1
  fi
done

# Containers from older versions of this script keep the credentials in their config
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Cleanup falls gewünscht
if $DO_CLEAN; then
  echo "Cleaning up..."
  rm -f "$USER_FILE"
fi

mkdir -p "$DATA_DIR"
chmod -R go-rwx "$DATA_DIR"

# Pass credentials via environment (name only), so they don't show up in `ps`.
# --rm drops them from `docker inspect` when the sync ends.
GARMIN_USERNAME="$(op read op://private/garmin/username)"
GARMIN_PASSWORD="$(op read op://private/garmin/password)"
export GARMIN_USERNAME GARMIN_PASSWORD
CMD=(
  docker run --rm -v "$DATA_DIR:/root" --interactive --tty
  --name "$CONTAINER_NAME"
  -e GARMIN_USERNAME -e GARMIN_PASSWORD
  "$IMAGE"
)
if [[ -n "$FROMDATE" ]]; then
  CMD+=(--fromdate "$FROMDATE")
fi
"${CMD[@]}"
