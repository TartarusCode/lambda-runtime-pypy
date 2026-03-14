#!/bin/bash
set -euo pipefail

if [[ -z "${PYPY_VERSION:-}" ]]; then
    echo "PYPY_VERSION must be set" >&2
    exit 1
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ ${PYPY_VERSION} != pypy3\.* ]]; then
    echo "Only PyPy 3 runtimes are supported for new builds: ${PYPY_VERSION}" >&2
    exit 1
fi

checksum_for() {
    local pkg_name=$1
    awk -v pkg="${pkg_name}" '$2 == pkg { print $1 }' "${REPO_ROOT}/checksums/pypy.sha256"
}

verify_sha256() {
    local archive_path=$1
    local archive_name=$2
    local expected
    expected=$(checksum_for "${archive_name}")

    if [[ -z "${expected}" ]]; then
        echo "Missing checksum for ${archive_name}" >&2
        exit 1
    fi

    if type -P sha256sum >/dev/null; then
        echo "${expected}  ${archive_path}" | sha256sum --check --status
    else
        local actual
        actual=$(shasum -a 256 "${archive_path}" | awk '{ print $1 }')
        [[ "${actual}" == "${expected}" ]]
    fi
}

rm -rf "layer/${PYPY_VERSION}" "${PYPY_VERSION}.zip"
mkdir -p "layer/${PYPY_VERSION}"
cp bootstrap.py3 "layer/${PYPY_VERSION}/bootstrap"
chmod +x "layer/${PYPY_VERSION}/bootstrap"

pushd layer >/dev/null
PKG_NAME="${PYPY_VERSION}-linux64"
BZIP_FILE="${PKG_NAME}.tar.bz2"
DOWNLOAD_URL="https://downloads.python.org/pypy/${BZIP_FILE}"

if [[ ! -f "${BZIP_FILE}" ]]; then
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "${BZIP_FILE}" "${DOWNLOAD_URL}"
fi

verify_sha256 "${BZIP_FILE}" "${BZIP_FILE}"

pushd "${PYPY_VERSION}" >/dev/null
tar -xjf "../${BZIP_FILE}"
mv "${PKG_NAME}" pypy
mkdir -p pypy/site-packages
cp -R "${REPO_ROOT}/runtime_helpers/lambda_runtime_pypy" pypy/site-packages/

if [[ -x "${REPO_ROOT}/audit.sh" ]]; then
    PYPY_VERSION="${PYPY_VERSION}" "${REPO_ROOT}/audit.sh" --best-effort
fi

zip -qr "../../${PYPY_VERSION}.zip" .
popd >/dev/null
popd >/dev/null
