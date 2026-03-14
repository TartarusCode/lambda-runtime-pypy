#!/bin/bash
set -euo pipefail

source conf.sh

RUNTIME_ZIP="${PYPY_VERSION}.zip"
SHA256SUM=$(type -P sha256sum >/dev/null && sha256sum "$RUNTIME_ZIP" | awk '{ print $1 }' || shasum -a 256 "$RUNTIME_ZIP" | awk '{ print $1 }')
PYPY=${PYPY_VERSION//-*}
S3KEY="${PYPY}/${SHA256SUM}.zip"

for region in "${PYPY_REGIONS[@]}"; do
  bucket_name="${bucket_base_name}-${region}"

  echo "Uploading $RUNTIME_ZIP to s3://${bucket_name}/${S3KEY}"

  aws --region "$region" s3 cp "$RUNTIME_ZIP" "s3://${bucket_name}/${S3KEY}"
done
