#!/usr/bin/env bash
# Renders every script the way macOS sees it, so shellcheck can read it. A Linux
# rendering would stop at the `exit 0` from script_darwin_only.
# Also enforces the shebang rule from AGENTS.md on the rendered result.

set -euo pipefail

out="$1"
root="$(cd "$(dirname "$0")/../.." && pwd)"
state="$(mktemp -d)"
trap 'rm -rf "$state"' EXIT

cat > "$state/chezmoi.toml" <<'EOF'
[data]
  name = "ci"
  email = "ci@example.org"
  installmas = "yes"
  lostcontact = "ci@example.org"
EOF

render() {
  chezmoi --source "$root" --config "$state/chezmoi.toml" --persistent-state "$state/state" \
    execute-template --override-data '{"chezmoi":{"os":"darwin"}}' < "$1"
}

mkdir -p "$out"
failed=0
for file in "$root"/home/.chezmoiscripts/*; do
  name="$(basename "$file" .tmpl)"
  case "$file" in
    *.tmpl) render "$file" > "$out/$name" ;;
    *) cp "$file" "$out/$name" ;;
  esac
  # chezmoi skips scripts that render empty
  if ! grep -q '[^[:space:]]' "$out/$name"; then
    echo "$name renders empty, skipping"
    rm -f "$out/$name"
    continue
  fi
  if [ "$(head -n 1 "$out/$name")" != "#!/usr/bin/env bash" ]; then
    echo "::error::$name has no bash shebang on line 1 after rendering"
    failed=1
  fi
done

cp "$root"/bootstrap.sh "$root"/home/dot_local/bin/executable_* "$out/"
ls -1 "$out"
exit "$failed"
