#!/bin/bash
set -euo pipefail

best_effort=0
if [[ "${1:-}" == "--best-effort" ]]; then
    best_effort=1
fi

if [[ -z "${PYPY_VERSION:-}" ]]; then
    echo "PYPY_VERSION must be set" >&2
    exit 1
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
target_dir="${REPO_ROOT}/layer/${PYPY_VERSION}"
if [[ ! -d "${target_dir}" ]]; then
    echo "Expected extracted runtime at ${target_dir}" >&2
    exit 1
fi

if type -P trivy >/dev/null; then
    trivy fs --quiet --severity HIGH,CRITICAL --exit-code 1 "${target_dir}"
    exit 0
fi

if type -P grype >/dev/null; then
    grype "dir:${target_dir}" --fail-on high --only-fixed
    exit 0
fi

message="Install trivy or grype to perform runtime vulnerability scanning"
if (( best_effort )); then
    echo "${message}" >&2
    exit 0
fi

echo "${message}" >&2
exit 1
