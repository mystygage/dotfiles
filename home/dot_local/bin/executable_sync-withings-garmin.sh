#!/usr/bin/env bash

set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/withings-sync"
USER_FILE="$DATA_DIR/.withings_user.json"
CONTAINER_NAME="withings"
IMAGE="ghcr.io/jaroslawhartman/withings-sync:master"

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
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Cleanup falls gewünscht
if $DO_CLEAN; then
  echo "Cleaning up..."
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -f "$USER_FILE"
fi

# Start/Init
if [[ ! -f "$USER_FILE" ]]; then
  CMD=(
    docker run -v "$DATA_DIR:/root" --interactive --tty
    --name "$CONTAINER_NAME"
    "$IMAGE"
    --garmin-username="$(op read op://private/garmin/username)"
    --garmin-password="$(op read op://private/garmin/password)"
  )
  if [[ -n "$FROMDATE" ]]; then
    CMD+=(--fromdate "$FROMDATE")
  fi
  "${CMD[@]}"
else
  docker start -i "$CONTAINER_NAME"
fi
