#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  show_manifest_history.sh <environment> <component> [options]

Description:
  Download and print the deployment manifest index for a component/environment from S3.
  This is a local-operator helper for investigating deployment history without manually
  opening individual manifest objects in the bucket.

Arguments:
  environment   Deployment environment, for example dev or prod.
  component     Deployable component, for example frontend or backend.

Options:
  --project <name>     Project prefix used in S3 keys. Default: lirw-ecs
  --bucket <name>      Explicit manifest bucket override.
  --limit <n>          Maximum number of entries to print. Default: 10
  --json               Print raw filtered JSON instead of a table.
  --help               Show this help text.

Examples:
  ./scripts/show_manifest_history.sh dev backend
  ./scripts/show_manifest_history.sh prod frontend --limit 20
  ./scripts/show_manifest_history.sh dev backend --json
  ./scripts/show_manifest_history.sh prod backend --bucket lirw-ecs-deployment-manifests-prod
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
LIMIT=10
OUTPUT_MODE="table"

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
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --json)
      OUTPUT_MODE="json"
      shift
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

FILTERED_JSON="$(jq --argjson limit "$LIMIT" '
  {
    project,
    environment,
    component,
    updatedAt,
    entries: (
      (.entries // [])
      | sort_by(.deployedAt // "")
      | reverse
      | .[:$limit]
    )
  }
' "$INDEX_FILE")"

if [ "$OUTPUT_MODE" = "json" ]; then
  echo "$FILTERED_JSON"
  exit 0
fi

echo "Manifest history for ${PROJECT_NAME}/${ENVIRONMENT}/${COMPONENT}"
echo "Bucket: ${BUCKET_NAME}"
echo "Index : s3://${BUCKET_NAME}/${INDEX_KEY}"
echo

ENTRY_COUNT="$(echo "$FILTERED_JSON" | jq '.entries | length')"
if [ "$ENTRY_COUNT" -eq 0 ]; then
  echo "No manifest history entries found."
  exit 0
fi

echo "$FILTERED_JSON" | jq -r '
  .entries[]
  | [
      (.deployedAt // "-"),
      (.status // "-"),
      (.taskDefinitionArn // "-"),
      (.previousTaskDefinitionArn // "-"),
      (.releaseVersion // "-"),
      (.commitSha // "-"),
      (.manifestS3Key // "-")
    ]
  | @tsv
' | awk 'BEGIN {
    FS="\t";
    printf "%-22s %-14s %-70s %-70s %-18s %-42s %s\n",
      "DEPLOYED_AT", "STATUS", "TASK_DEFINITION_ARN", "PREVIOUS_TASK_DEF_ARN", "RELEASE_VERSION", "COMMIT_SHA", "MANIFEST_S3_KEY";
  }
  {
    printf "%-22s %-14s %-70s %-70s %-18s %-42s %s\n",
      $1, $2, $3, $4, $5, $6, $7;
  }'
