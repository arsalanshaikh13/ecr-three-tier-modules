#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/cleanup_task_definitions.sh --region <aws-region> [options]

Description:
  Deregister ACTIVE ECS task definition revisions and optionally hard-delete INACTIVE
  revisions for the task-definition families used by this infra. If no family is provided,
  the script uses the standard project families as a built-in backup/default set.

Options:
  --region <aws-region>         AWS region to operate against. Required.
  --project <name>              Project prefix. Default: lirw-ecs
  --environment <env>           Environment suffix for env-scoped families. Default: dev
  --family <family>             Optional explicit family name. Can be provided multiple times.
  --keep-latest <count>         Keep this many newest ACTIVE revisions per family. Default: 1
  --skip-delete-inactive        Deregister ACTIVE revisions only; do not hard-delete INACTIVE ones.
  --dry-run                     Show what would happen without making changes.
  --help                        Show this help text.

Examples:
  ./scripts/cleanup_task_definitions.sh --region us-east-1 --environment dev --dry-run
  ./scripts/cleanup_task_definitions.sh --region us-east-1 --environment dev --family lirw-ecs-backend
  ./scripts/cleanup_task_definitions.sh --region us-east-1 --environment prod --keep-latest 2
EOF
}

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

AWS_REGION="us-east-1"
PROJECT_NAME="lirw-ecs"
ENVIRONMENT="dev"
KEEP_LATEST=1
DRY_RUN="false"
DELETE_INACTIVE="true"
declare -a EXPLICIT_FAMILIES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --family)
      EXPLICIT_FAMILIES+=("$2")
      shift 2
      ;;
    --keep-latest)
      KEEP_LATEST="$2"
      shift 2
      ;;
    --skip-delete-inactive)
      DELETE_INACTIVE="false"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$AWS_REGION" ]; then
  echo "Error: --region is required." >&2
  exit 1
fi

if ! [[ "$KEEP_LATEST" =~ ^[0-9]+$ ]]; then
  echo "Error: --keep-latest must be a non-negative integer." >&2
  exit 1
fi

declare -a DEFAULT_FAMILIES=(
  "${PROJECT_NAME}-frontend"
  "${PROJECT_NAME}-backend"
  "${PROJECT_NAME}-probe-${ENVIRONMENT}"
  "${PROJECT_NAME}-db-seeder-${ENVIRONMENT}"
)

declare -a FAMILIES=()
if [ "${#EXPLICIT_FAMILIES[@]}" -gt 0 ]; then
  FAMILIES=("${EXPLICIT_FAMILIES[@]}")
else
  # These are the standard task-definition families used by the current infra. Keeping
  # them here means the script remains useful even when the operator does not pass a
  # family explicitly, while still allowing manual override for one-off cleanup.
  FAMILIES=("${DEFAULT_FAMILIES[@]}")
fi

dedupe_families() {
  declare -A seen=()
  for family in "${FAMILIES[@]}"; do
    if [ -n "${family}" ] && [ -z "${seen[$family]:-}" ]; then
      seen["$family"]=1
      printf '%s\n' "$family"
    fi
  done
}

run_or_echo() {
  if [ "$DRY_RUN" = "true" ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

deregister_active_revisions() {
  local family="$1"
  local -a active_arns=()
  local total_active=0
  local start_index=0

  mapfile -t active_arns < <(
    aws ecs list-task-definitions \
      --family-prefix "$family" \
      --status ACTIVE \
      --sort DESC \
      --region "$AWS_REGION" \
      --query 'taskDefinitionArns' \
      --output text | tr '\t' '\n' | sed '/^$/d'
  )

  total_active="${#active_arns[@]}"
  if [ "$total_active" -eq 0 ]; then
    echo "No ACTIVE revisions found for family: $family"
    return 0
  fi

  echo "Family: $family"
  echo "ACTIVE revisions found: $total_active"

  if [ "$KEEP_LATEST" -ge "$total_active" ]; then
    echo "Keeping all ACTIVE revisions because keep-latest=$KEEP_LATEST >= $total_active"
    return 0
  fi

  start_index="$KEEP_LATEST"
  for (( i=start_index; i<total_active; i++ )); do
    local arn="${active_arns[$i]}"
    echo "Deregistering ACTIVE revision: $arn"
    run_or_echo aws ecs deregister-task-definition \
      --task-definition "$arn" \
      --region "$AWS_REGION" \
      >/dev/null
  done
}

delete_inactive_revisions() {
  local family="$1"
  local -a inactive_arns=()

  if [ "$DELETE_INACTIVE" != "true" ]; then
    echo "Skipping hard delete of INACTIVE revisions for family: $family"
    return 0
  fi

  mapfile -t inactive_arns < <(
    aws ecs list-task-definitions \
      --family-prefix "$family" \
      --status INACTIVE \
      --sort DESC \
      --region "$AWS_REGION" \
      --query 'taskDefinitionArns' \
      --output text | tr '\t' '\n' | sed '/^$/d'
  )

  if [ "${#inactive_arns[@]}" -eq 0 ]; then
    echo "No INACTIVE revisions found for family: $family"
    return 0
  fi

  echo "INACTIVE revisions found for hard delete: ${#inactive_arns[@]}"
  for arn in "${inactive_arns[@]}"; do
    echo "Deleting INACTIVE revision: $arn"
    run_or_echo aws ecs delete-task-definitions \
      --task-definitions "$arn" \
      --region "$AWS_REGION" \
      >/dev/null
  done
}

echo "Region       : $AWS_REGION"
echo "Project      : $PROJECT_NAME"
echo "Environment  : $ENVIRONMENT"
echo "Keep latest  : $KEEP_LATEST"
echo "Dry run      : $DRY_RUN"
echo "Delete stale : $DELETE_INACTIVE"
echo

while IFS= read -r family; do
  [ -z "$family" ] && continue
  deregister_active_revisions "$family"
  delete_inactive_revisions "$family"
  echo
done < <(dedupe_families)
