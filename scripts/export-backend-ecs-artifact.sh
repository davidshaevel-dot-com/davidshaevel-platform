#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_PATH="${1:-}"
OUT_PATH="${2:-}"

if [[ -z "$ARTIFACT_PATH" || -z "$OUT_PATH" ]]; then
  echo "usage: $0 <artifact_path_in_container> <output_path>"
  echo
  echo "example:"
  echo "  $0 /tmp/cpu-2025-12-12T12-34-56.000Z.cpuprofile ./cpu.cpuprofile"
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 not found on PATH" >&2
  exit 1
fi

cd "$TF_ENV_DIR"

AWS_REGION="$(terraform output -raw aws_region)"
ECS_CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
BACKEND_SERVICE_NAME="$(terraform output -raw backend_service_name)"

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

echo "Exporting artifact from ECS task..."
echo "- region:   $AWS_REGION"
echo "- cluster:  $ECS_CLUSTER_NAME"
echo "- service:  $BACKEND_SERVICE_NAME"
echo "- task:     $TASK_ARN"
echo "- container:$CONTAINER_NAME"
echo "- path:     $ARTIFACT_PATH"
echo

# Use Node.js inside the container to base64-encode the file. This avoids relying on
# `base64` being present in the container image.
#
# We print explicit markers so we can reliably extract the payload from the exec output.
# Capture stderr (2>&1) so container errors are included in RAW_OUT for debugging.
RAW_OUT="$(aws ecs execute-command \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER_NAME" \
  --task "$TASK_ARN" \
  --container "$CONTAINER_NAME" \
  --interactive \
  --command "node -e \"const fs=require('fs'); const p=process.argv[1]; console.log('---BEGIN_ARTIFACT_B64---'); process.stdout.write(fs.readFileSync(p).toString('base64')); console.log('\\n---END_ARTIFACT_B64---');\" \"$ARTIFACT_PATH\"" 2>&1)"

python3 - <<'PY' "$RAW_OUT" "$OUT_PATH"
import base64
import re
import sys

raw = sys.argv[1]
out_path = sys.argv[2]

# The regex extracts base64 content between markers, ignoring any AWS SSM noise
# that may appear elsewhere in the output (e.g., "Cannot perform start session: EOF").
m = re.search(r"---BEGIN_ARTIFACT_B64---\\s*(?P<b64>[A-Za-z0-9+/=\\s]+)\\s*---END_ARTIFACT_B64---", raw)
if not m:
    print("error: could not find base64 payload in ECS exec output. See raw output below.", file=sys.stderr)
    print("hint: the file may not exist, the task may have been replaced, or an error occurred.", file=sys.stderr)
    print("\\n---[ RAW ECS OUTPUT ]---\\n" + raw, file=sys.stderr)
    sys.exit(1)

b64 = re.sub(r"\\s+", "", m.group("b64"))
data = base64.b64decode(b64)

with open(out_path, "wb") as f:
    f.write(data)

print(f"Wrote {len(data)} bytes to {out_path}")
PY
