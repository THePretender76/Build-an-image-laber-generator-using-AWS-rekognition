#!/usr/bin/env bash
# Deploy VisionCraft AI from a Bash environment (Linux, macOS, Git Bash, or WSL).
set -euo pipefail

STACK_NAME="${STACK_NAME:-visioncraft-stack}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
PROJECT_PREFIX="${PROJECT_PREFIX:-visioncraft}"
TEMPLATE_FILE="${TEMPLATE_FILE:-./Cloudformation file/infrastructure-vision-craft.yml}"
PILLOW_LAYER_ARN="${PILLOW_LAYER_ARN:?Set PILLOW_LAYER_ARN to the ARN of your Python 3.11 Pillow layer.}"
ALLOWED_ORIGIN="${ALLOWED_ORIGIN:-*}"
PACKAGE_DIRECTORY=""
PYTHON_BIN="${PYTHON_BIN:-}"

cleanup() {
  if [[ -n "$PACKAGE_DIRECTORY" && -d "$PACKAGE_DIRECTORY" ]]; then
    rm -rf "$PACKAGE_DIRECTORY"
  fi
}
trap cleanup EXIT

echo "=== VisionCraft AI deployment ==="
echo "Region: $REGION"
echo "Stack: $STACK_NAME"

if [[ -z "$PYTHON_BIN" ]]; then
  for candidate in python3 python py; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "Required command not found: aws" >&2
  exit 1
fi
if [[ -z "$PYTHON_BIN" ]] || ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3 is required (tried python3, python, and py)." >&2
  exit 1
fi

if ! aws sts get-caller-identity --region "$REGION" >/dev/null; then
  echo "AWS credentials are not configured. Run 'aws configure' or 'aws sso login'." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "CloudFormation template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query Account --output text)
ARTIFACT_BUCKET="${PROJECT_PREFIX}-artifacts-${ACCOUNT_ID}-${REGION}"
BUILD_ID=$(date -u +%Y%m%dT%H%M%SZ)
PROCESSOR_KEY="lambda/process_image_add_label-${BUILD_ID}.zip"
PRESIGNED_KEY="lambda/get_presigned_url-${BUILD_ID}.zip"

echo "Preparing Lambda packages..."
PACKAGE_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/visioncraft.XXXXXX")
PROCESSOR_ZIP="$PACKAGE_DIRECTORY/process_image_add_label.zip"
PRESIGNED_ZIP="$PACKAGE_DIRECTORY/get_presigned_url.zip"

"$PYTHON_BIN" - "$PROCESSOR_ZIP" "fichier projet/process_image_add_label.py" <<'PY'
import sys
import zipfile

archive, source = sys.argv[1:]
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(source, "process_image_add_label.py")
PY
"$PYTHON_BIN" - "$PRESIGNED_ZIP" "fichier projet/get_presigned_url.py" <<'PY'
import sys
import zipfile

archive, source = sys.argv[1:]
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(source, "get_presigned_url.py")
PY

echo "Ensuring private artifact bucket exists: $ARTIFACT_BUCKET"
if ! aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" 2>/dev/null; then
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi

echo "Uploading Lambda packages..."
aws s3 cp "$PROCESSOR_ZIP" "s3://$ARTIFACT_BUCKET/$PROCESSOR_KEY" --region "$REGION"
aws s3 cp "$PRESIGNED_ZIP" "s3://$ARTIFACT_BUCKET/$PRESIGNED_KEY" --region "$REGION"

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
  --region "$REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "ProjectPrefix=$PROJECT_PREFIX" \
    "PillowLayerArn=$PILLOW_LAYER_ARN" \
    "AllowedOrigin=$ALLOWED_ORIGIN" \
    "ProcessorCodeBucket=$ARTIFACT_BUCKET" \
    "ProcessorCodeKey=$PROCESSOR_KEY" \
    "PresignedCodeBucket=$ARTIFACT_BUCKET" \
    "PresignedCodeKey=$PRESIGNED_KEY"

echo "Retrieving stack outputs..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs' --output json)
FRONTEND_URL=$("$PYTHON_BIN" -c 'import json,sys; print(next((o["OutputValue"] for o in json.load(sys.stdin) if o["OutputKey"] == "WebsiteURL"), ""))' <<<"$STACK_OUTPUTS")
PRESIGNED_URL=$("$PYTHON_BIN" -c 'import json,sys; print(next((o["OutputValue"] for o in json.load(sys.stdin) if o["OutputKey"] == "PresignedFunctionUrl"), ""))' <<<"$STACK_OUTPUTS")
FRONTEND_BUCKET=$("$PYTHON_BIN" -c 'import json,sys; print(next((o["OutputValue"] for o in json.load(sys.stdin) if o["OutputKey"] == "FrontendBucketName"), ""))' <<<"$STACK_OUTPUTS")

if [[ -z "$FRONTEND_URL" || -z "$PRESIGNED_URL" || -z "$FRONTEND_BUCKET" ]]; then
  echo "One or more expected CloudFormation outputs are missing." >&2
  exit 1
fi

echo "Publishing configured frontend..."
TEMP_FRONTEND="$PACKAGE_DIRECTORY/index.html"
"$PYTHON_BIN" - "$PRESIGNED_URL" "$TEMP_FRONTEND" <<'PY'
import pathlib
import sys

url, destination = sys.argv[1:]
source = pathlib.Path("index.html").read_text(encoding="utf-8")
marker = "const LAMBDA_URL = '__LAMBDA_FUNCTION_URL__';"
if marker not in source:
    raise SystemExit("The Lambda URL marker was not found in index.html.")
destination = pathlib.Path(destination)
destination.write_text(source.replace(marker, f"const LAMBDA_URL = {url!r};"), encoding="utf-8")
PY
aws s3 cp "$TEMP_FRONTEND" "s3://$FRONTEND_BUCKET/index.html" \
  --content-type "text/html; charset=utf-8" --region "$REGION"

echo
echo "Deployment complete. Open: $FRONTEND_URL"
