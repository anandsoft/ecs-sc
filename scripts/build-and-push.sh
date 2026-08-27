#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/terraform"

REGION="$(terraform output -raw aws_region 2>/dev/null || true)"
if [[ -z "${REGION}" ]]; then
  REGION="$(terraform console <<< 'var.aws_region' 2>/dev/null | tr -d '"' || true)"
fi
REGION="${REGION:-us-east-1}"

eval "$(terraform output -json ecr_repository_urls | python3 -c '
import json,sys
urls=json.load(sys.stdin)
for k,v in urls.items():
    print(f"{k.upper()}_URL={v}")
')"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text --region "$REGION")"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

TAG="${IMAGE_TAG:-latest}"

docker build -t "${UI_URL}:${TAG}" "$ROOT/apps/ui"
docker build -t "${CATALOG_URL}:${TAG}" "$ROOT/apps/catalog"
docker build -t "${SALES_URL}:${TAG}" "$ROOT/apps/sales"

docker push "${UI_URL}:${TAG}"
docker push "${CATALOG_URL}:${TAG}"
docker push "${SALES_URL}:${TAG}"
