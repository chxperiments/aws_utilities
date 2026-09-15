#!/usr/bin/env bash
# Builds and publishes the Lambda layer used by rds-restore-test-validation.yaml.
# Contents: pg8000 + oracledb (python3.13, x86_64) and the RDS CA bundle at /opt/rds-global-bundle.pem.
# Usage: ./build-driver-layer.sh [region]    -> prints the layer ARN to pass as DriverLayerArn
set -euo pipefail

REGION="${1:-${AWS_REGION:-$(aws configure get region)}}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pip install --quiet \
  --platform manylinux2014_x86_64 --platform manylinux_2_17_x86_64 --platform manylinux_2_28_x86_64 \
  --implementation cp --python-version 3.13 --only-binary=:all: \
  --target "$WORK/python" pg8000 oracledb

curl -fsSL -o "$WORK/rds-global-bundle.pem" \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

(cd "$WORK" && zip -qr layer.zip python rds-global-bundle.pem)

aws lambda publish-layer-version \
  --region "$REGION" \
  --layer-name restore-test-db-drivers \
  --description "pg8000 + oracledb + RDS CA bundle" \
  --compatible-runtimes python3.13 \
  --compatible-architectures x86_64 \
  --zip-file "fileb://$WORK/layer.zip" \
  --query LayerVersionArn --output text
