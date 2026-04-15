#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  get_rollback_target.sh <environment> <component> [options]

Description:
  Resolve a rollback target from deployment manifest history. By default this script
  returns the most recent successful revision prior to the current trusted revision.
  It is machine-friendly and suitable for local operator scripting.

Arguments:
  environment   Deployment environment, for example dev or prod.
  component     Deployable component, for example frontend or backend.

Options:
  --project <name>        Project prefix used in S3 keys. Default: lirw-ecs
  --bucket <name>         Explicit manifest bucket override.
  --current-arn <arn>     Treat this task definition as the current trusted revision.
  --output <field>        One of: task-definition-arn, previous-task-definition-arn,
                          manifest-s3-key, reason, json. Default: task-definition-arn
  --help                  Show this help text.

Examples:
  ./scripts/get_rollback_target.sh dev backend
  ./scripts/get_rollback_target.sh prod frontend --output json
  ./scripts/get_rollback_target.sh dev backend --current-arn arn:aws:ecs:...
EOF
}

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 1
fi

if [ "${1:-}" = "--help" ] || [ $# -lt 2 ]; then
  usage
  exit 0
fi

ENVIRONMENT="$1"
COMPONENT="$2"
shift 2

PROJECT_NAME="lirw-ecs"
BUCKET_NAME=""
CURRENT_TASK_DEF_ARN=""
OUTPUT_FIELD="task-definition-arn"

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --current-arn)
      CURRENT_TASK_DEF_ARN="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FIELD="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$BUCKET_NAME" ]; then
  BUCKET_NAME="${PROJECT_NAME}-deployment-manifests-${ENVIRONMENT}"
fi

INDEX_KEY="${PROJECT_NAME}/deployments/${ENVIRONMENT}/${COMPONENT}/manifest-index.json"
INDEX_FILE="$(mktemp)"

cleanup() {
  rm -f "$INDEX_FILE"
}
trap cleanup EXIT

aws s3 cp "s3://${BUCKET_NAME}/${INDEX_KEY}" "$INDEX_FILE" >/dev/null

if [ -z "$CURRENT_TASK_DEF_ARN" ]; then
  CURRENT_TASK_DEF_ARN="$(jq -r '
    (.entries // [])
    | map(select(.status == "successful"))
    | sort_by(.deployedAt // "")
    | reverse
    | (.[0].taskDefinitionArn // "")
  ' "$INDEX_FILE")"
fi

if [ -z "$CURRENT_TASK_DEF_ARN" ] || [ "$CURRENT_TASK_DEF_ARN" = "null" ]; then
  echo "Error: could not determine the current trusted task definition ARN from manifest history." >&2
  exit 1
fi

RESULT_JSON="$(jq -r --arg currentTaskDef "$CURRENT_TASK_DEF_ARN" '
  def successful_entries:
    (.entries // [])
    | map(select(.status == "successful"))
    | sort_by(.deployedAt // "")
    | reverse;

  (successful_entries) as $entries
  | ($entries | map(select(.taskDefinitionArn == $currentTaskDef)) | .[0]) as $current
  | if $current == null then
      {
        taskDefinitionArn: null,
        previousTaskDefinitionArn: null,
        manifestS3Key: null,
        reason: "Current trusted task definition was not found in successful manifest history."
      }
    else
      {
        taskDefinitionArn: ($current.previousTaskDefinitionArn // null),
        previousTaskDefinitionArn: (
          $entries
          | map(select(.taskDefinitionArn == ($current.previousTaskDefinitionArn // "")))
          | .[0].previousTaskDefinitionArn // null
        ),
        manifestS3Key: $current.manifestS3Key,
        reason: (
          if ($current.previousTaskDefinitionArn // "") == "" then
            "Current trusted revision has no recorded parent successful revision."
          else
            "Resolved rollback target from the previousTaskDefinitionArn recorded on the current trusted successful manifest."
          end
        )
      }
    end
' "$INDEX_FILE")"

RESOLVED_TASK_DEF="$(echo "$RESULT_JSON" | jq -r '.taskDefinitionArn // ""')"
if [ -z "$RESOLVED_TASK_DEF" ]; then
  echo "Error: no rollback target was found." >&2
  echo "$RESULT_JSON" | jq .
  exit 1
fi

case "$OUTPUT_FIELD" in
  task-definition-arn)
    echo "$RESULT_JSON" | jq -r '.taskDefinitionArn'
    ;;
  previous-task-definition-arn)
    echo "$RESULT_JSON" | jq -r '.previousTaskDefinitionArn // ""'
    ;;
  manifest-s3-key)
    echo "$RESULT_JSON" | jq -r '.manifestS3Key // ""'
    ;;
  reason)
    echo "$RESULT_JSON" | jq -r '.reason'
    ;;
  json)
    echo "$RESULT_JSON" | jq .
    ;;
  *)
    echo "Error: unsupported output field '$OUTPUT_FIELD'." >&2
    usage
    exit 1
    ;;
esac
