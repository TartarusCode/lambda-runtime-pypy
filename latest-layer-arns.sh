#!/bin/bash
set -euo pipefail

source conf.sh

PYPY=${PYPY_VERSION//-*}

for region in "${PYPY_REGIONS[@]}"; do
    latest_arn=$(aws --region "$region" lambda list-layer-versions --layer-name "${PYPY//.}" --output text --query "LayerVersions[0].LayerVersionArn")
    echo "* ${region}: \`${latest_arn}\`"
done
