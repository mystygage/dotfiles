#!/usr/bin/env bash

# Load an existing kubeconfig in ~/.kube/config
DEFAULT_KUBECONFIG_FILE="$HOME/.kube/config"
if test -f "${DEFAULT_KUBECONFIG_FILE}"
then
  export KUBECONFIG="$DEFAULT_KUBECONFIG_FILE"
fi

# Additional kubeconfig files should be inside ~/.kube/config-files
ADD_KUBECONFIG_FILES="$HOME/.kube/config-files"
mkdir -p "${ADD_KUBECONFIG_FILES}"

# Cache the assembled KUBECONFIG list and only rebuild when the directory
# mtime changes (avoids a `find` on every shell startup).
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
CACHE_FILE="${CACHE_DIR}/kubeconfig-list"
STAMP_FILE="${CACHE_DIR}/kubeconfig-list.stamp"
mkdir -p "${CACHE_DIR}"

current_stamp=$(stat -f %m "${ADD_KUBECONFIG_FILES}" 2>/dev/null || stat -c %Y "${ADD_KUBECONFIG_FILES}" 2>/dev/null)
cached_stamp=$(cat "${STAMP_FILE}" 2>/dev/null)

if [[ ! -s "${CACHE_FILE}" || "${current_stamp}" != "${cached_stamp}" ]]; then
  extra=""
  while IFS= read -r -d '' kubeconfigFile; do
    extra="${kubeconfigFile}:${extra}"
  done < <(find "${ADD_KUBECONFIG_FILES}" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0)
  printf '%s' "${extra}" >| "${CACHE_FILE}"
  printf '%s' "${current_stamp}" >| "${STAMP_FILE}"
fi

extra_configs=$(cat "${CACHE_FILE}")
if [[ -n "${extra_configs}" ]]; then
  export KUBECONFIG="${extra_configs}${KUBECONFIG}"
fi
