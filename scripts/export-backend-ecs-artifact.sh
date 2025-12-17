#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Export Profiling Artifact from ECS Backend Task via S3
# =============================================================================
#
# This script exports profiling artifacts (CPU profiles, heap snapshots) from
# an ECS backend task to the local machine using S3 as an intermediary.
#
# Workflow:
# 1. Upload artifact from container to S3 using ECS Exec
# 2. Download artifact from S3 to local machine
# 3. Clean up S3 artifact
#
# Prerequisites:
# - enable_profiling_artifacts_bucket = true in Terraform
# - AWS CLI configured with appropriate permissions
# - ECS Exec enabled for the backend service
#
# =============================================================================

ARTIFACT_PATH="${1:-}"
OUT_PATH="${2:-}"

if [[ -z "$ARTIFACT_PATH" || -z "$OUT_PATH" ]]; then
  echo "usage: $0 <artifact_path_in_container> <output_path>"
  echo
  echo "example:"
  echo "  $0 /tmp/cpu-2025-12-12T12-34-56.000Z.cpuprofile ./cpu.cpuprofile"
  echo
  echo "environment variables:"
  echo "  TASK_ARN        - Specify a task ARN directly (useful with multiple tasks)"
  echo "  TF_ENV_DIR      - Terraform environment directory (default: terraform/environments/dev)"
  echo "  CONTAINER_NAME  - Container name (default: backend)"
  echo
  echo "example with specific task:"
  echo "  TASK_ARN=arn:aws:ecs:us-east-1:123:task/cluster/abc123 $0 /tmp/cpu.cpuprofile ./cpu.cpuprofile"
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_ENV_DIR="${TF_ENV_DIR:-$ROOT_DIR/terraform/environments/dev}"
CONTAINER_NAME="${CONTAINER_NAME:-backend}"

if [[ ! -d "$TF_ENV_DIR" ]]; then
  echo "error: TF_ENV_DIR not found: $TF_ENV_DIR" >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "error: terraform not found on PATH" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "error: aws not found on PATH" >&2
  exit 1
fi

cd "$TF_ENV_DIR"

AWS_REGION="$(terraform output -raw aws_region)"
ECS_CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
BACKEND_SERVICE_NAME="$(terraform output -raw backend_service_name)"
BUCKET_NAME="$(terraform output -raw profiling_artifacts_bucket_name)"

if [[ -z "$BUCKET_NAME" ]]; then
  echo "error: profiling artifacts bucket not enabled" >&2
  echo "hint: set enable_profiling_artifacts_bucket = true in Terraform and apply" >&2
  exit 1
fi

# Allow overriding the task ARN via environment variable.
# Useful when multiple tasks are running (high availability) and the artifact
# is on a specific task. See troubleshooting docs for how to identify which task has your artifact.
if [[ -n "${TASK_ARN:-}" ]]; then
  echo "Using TASK_ARN from environment: $TASK_ARN"
else
  TASK_ARN="$(aws ecs list-tasks \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER_NAME" \
    --service-name "$BACKEND_SERVICE_NAME" \
    --desired-status RUNNING \
    --query 'taskArns[0]' \
    --output text)"

  if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
    echo "error: could not find a RUNNING task for service: $BACKEND_SERVICE_NAME" >&2
    exit 1
  fi
fi

# Generate a unique S3 key for this artifact
ARTIFACT_FILENAME="$(basename "$ARTIFACT_PATH")"
S3_KEY="exports/$(date +%Y%m%d-%H%M%S)-${ARTIFACT_FILENAME}"

echo "Exporting artifact from ECS task via S3..."
echo "- region:    $AWS_REGION"
echo "- cluster:   $ECS_CLUSTER_NAME"
echo "- service:   $BACKEND_SERVICE_NAME"
echo "- task:      $TASK_ARN"
echo "- container: $CONTAINER_NAME"
echo "- path:      $ARTIFACT_PATH"
echo "- bucket:    $BUCKET_NAME"
echo "- s3_key:    $S3_KEY"
echo

# Step 1: Upload artifact from container to S3 using ECS Exec
echo "Step 1/3: Uploading artifact to S3..."
aws ecs execute-command \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER_NAME" \
  --task "$TASK_ARN" \
  --container "$CONTAINER_NAME" \
  --interactive \
  --command "aws s3 cp '$ARTIFACT_PATH' 's3://$BUCKET_NAME/$S3_KEY' --region $AWS_REGION"

# Step 2: Download artifact from S3 to local machine
echo "Step 2/3: Downloading artifact from S3..."
aws s3 cp "s3://$BUCKET_NAME/$S3_KEY" "$OUT_PATH" --region "$AWS_REGION"

# Step 3: Clean up S3 artifact
echo "Step 3/3: Cleaning up S3 artifact..."
aws s3 rm "s3://$BUCKET_NAME/$S3_KEY" --region "$AWS_REGION"

# Report success
FILE_SIZE="$(wc -c < "$OUT_PATH" | tr -d ' ')"
echo
echo "Success! Exported $FILE_SIZE bytes to $OUT_PATH"
