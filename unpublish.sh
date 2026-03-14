#!/bin/bash
set -euo pipefail

VERSION=$1

source conf.sh

RUNTIME_ZIP="${PYPY_VERSION}.zip"
SHA256SUM=$(type -P sha256sum >/dev/null && sha256sum "$RUNTIME_ZIP" | awk '{ print $1 }' || shasum -a 256 "$RUNTIME_ZIP" | awk '{ print $1 }')
PYPY=${PYPY_VERSION//-*}
S3KEY="${PYPY}/${SHA256SUM}.zip"

for region in "${PYPY_REGIONS[@]}"; do
  bucket_name="${bucket_base_name}-${region}"

  echo "Deleting Lambda Layer ${PYPY} version ${VERSION} in region ${region}..."
  aws --region "$region" lambda delete-layer-version --layer-name "${PYPY//.}" --version-number "$VERSION"
  echo "Deleted Lambda Layer ${PYPY} version ${VERSION} in region ${region}"
done
