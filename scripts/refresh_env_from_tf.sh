#!/bin/bash
set -euo pipefail

# Refresh GitHub Environment variables from Terraform outputs and established
# environment naming conventions. This keeps workflow-facing configuration in
# sync with infrastructure changes without editing workflow YAML directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../root"

GH_USER="${GH_USER:-arsalanshaikh13}"
REPO_NAME="${REPO_NAME:-ecr-three-tier-modules}"
REPO="${GH_USER}/${REPO_NAME}"

usage() {
  cat <<'EOF'
Usage: ./scripts/refresh_env_from_tf.sh [--mode apply|dry-run|diff] [--only all|baseline|telemetry|network|notifications] <dev|prod|all>

What it does:
1. Refreshes baseline runtime GitHub Environment variables
2. Reads Phase 3 telemetry alarm CSV outputs from the environment-specific Terraform state
3. Writes GitHub Environment variables for:
   - FRONTEND_RELEASE_ALARM_NAMES
   - BACKEND_RELEASE_ALARM_NAMES
4. Refreshes subnet, security-group, launch-type, network-mode, and public-IP
   variables used by deploy / probe / seeder jobs
5. Refreshes notification topic variables used by Phase 7 email notifications

Defaults:
- repo: arsalanshaikh13/ecr-three-tier-modules
- mode: apply
- section: all

Override repository target if needed:
- GH_USER=<owner> REPO_NAME=<repo> ./scripts/refresh_env_from_tf.sh dev

Preview changes without writing to GitHub:
- ./scripts/refresh_env_from_tf.sh --mode dry-run dev

Show current vs proposed GitHub Environment variable values:
- ./scripts/refresh_env_from_tf.sh --mode diff dev

Refresh only telemetry variables:
- ./scripts/refresh_env_from_tf.sh --only telemetry prod
- ./scripts/refresh_env_from_tf.sh --only notifications prod

Refresh only baseline and network variables:
- ./scripts/refresh_env_from_tf.sh --only baseline dev
- ./scripts/refresh_env_from_tf.sh --only network dev
EOF
}

MODE="apply"
ONLY_SECTION="all"
TARGET_ENV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --only)
      ONLY_SECTION="${2:-}"
      shift 2
      ;;
    dev|prod|all)
      TARGET_ENV="$1"
      shift
      ;;
    *)
      echo "Error: unknown argument '$1'."
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "apply" && "$MODE" != "dry-run" && "$MODE" != "diff" ]]; then
  echo "Error: unsupported mode '$MODE'."
  usage
  exit 1
fi

if [[ "$ONLY_SECTION" != "all" && "$ONLY_SECTION" != "baseline" && "$ONLY_SECTION" != "telemetry" && "$ONLY_SECTION" != "network" && "$ONLY_SECTION" != "notifications" ]]; then
  echo "Error: unsupported section '$ONLY_SECTION'."
  usage
  exit 1
fi

if [[ "$TARGET_ENV" != "dev" && "$TARGET_ENV" != "prod" && "$TARGET_ENV" != "all" ]]; then
  usage
  exit 1
fi

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' was not found."
    exit 1
  fi
}

require_command gh
require_command terraform

should_sync_section() {
  local requested="$1"
  [[ "$ONLY_SECTION" == "all" || "$ONLY_SECTION" == "$requested" ]]
}

get_current_env_var() {
  local env_name="$1"
  local var_name="$2"

  # Resolve current GitHub Environment variable value so diff mode can compare
  # the live control-plane state against the Terraform-derived proposal.
  gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/$env_name/variables/$var_name" \
    --jq '.value' 2>/dev/null || true
}

get_current_repo_var() {
  local var_name="$1"

  gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/actions/variables/$var_name" \
    --jq '.value' 2>/dev/null || true
}

sync_env_var() {
  local env_name="$1"
  local var_name="$2"
  local var_value="$3"

  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] Would set ${env_name}:${var_name}=${var_value}"
  elif [[ "$MODE" == "diff" ]]; then
    local current_value
    current_value="$(get_current_env_var "$env_name" "$var_name")"

    if [[ -z "$current_value" ]]; then
      echo "[diff] ${env_name}:${var_name}"
      echo "  current : <missing>"
      echo "  proposed: ${var_value}"
      echo "  status  : different"
    elif [[ "$current_value" == "$var_value" ]]; then
      echo "[diff] ${env_name}:${var_name}"
      echo "  current : ${current_value}"
      echo "  proposed: ${var_value}"
      echo "  status  : same"
    else
      echo "[diff] ${env_name}:${var_name}"
      echo "  current : ${current_value}"
      echo "  proposed: ${var_value}"
      echo "  status  : different"
    fi
  else
    echo "Setting ${env_name}:${var_name}=${var_value}"
    gh variable set "$var_name" \
      --repo "$REPO" \
      --env "$env_name" \
      --body "$var_value"
  fi
}

sync_repo_var() {
  local var_name="$1"
  local var_value="$2"

  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] Would set repo:${var_name}=${var_value}"
  elif [[ "$MODE" == "diff" ]]; then
    local current_value
    current_value="$(get_current_repo_var "$var_name")"

    if [[ -z "$current_value" ]]; then
      echo "[diff] repo:${var_name}"
      echo "  current : <missing>"
      echo "  proposed: ${var_value}"
      echo "  status  : different"
    elif [[ "$current_value" == "$var_value" ]]; then
      echo "[diff] repo:${var_name}"
      echo "  current : ${current_value}"
      echo "  proposed: ${var_value}"
      echo "  status  : same"
    else
      echo "[diff] repo:${var_name}"
      echo "  current : ${current_value}"
      echo "  proposed: ${var_value}"
      echo "  status  : different"
    fi
  else
    echo "Setting repo:${var_name}=${var_value}"
    gh variable set "$var_name" \
      --repo "$REPO" \
      --body "$var_value"
  fi
}

sync_baseline_runtime_vars() {
  local env_name="$1"
  local aws_region="$2"
  local deployment_manifest_bucket="$3"

  # These are the common execution-scoped variables consumed directly by the
  # reusable workflows and actions across deploy, promotion, rollback, probe,
  # and seeding paths.
  sync_env_var "$env_name" ENV_VAR "$env_name"
  sync_env_var "$env_name" ACCOUNT_ID "750702272407"
  sync_env_var "$env_name" PROJECT_NAME "lirw-ecs"
  sync_env_var "$env_name" AWS_REGION "$aws_region"
  sync_env_var "$env_name" DEPLOYMENT_MANIFEST_BUCKET "$deployment_manifest_bucket"
  sync_env_var "$env_name" DEPLOYMENT_MANIFEST_BUCKET_PREFIX "lirw-ecs-deployment-manifests"
}

terraform_output_from_state() {
  local state_file="$1"
  local output_name="$2"

  terraform -chdir="$ROOT_DIR" output -state="$state_file" -raw "$output_name"
}

sync_phase3_telemetry_from_tf() {
  local env_name="$1"
  local state_file="$2"

  # Alarm names are infrastructure-derived identifiers, so Terraform is the
  # cleanest source of truth for the telemetry gate contract.
  local frontend_alarm_names
  local backend_alarm_names

  frontend_alarm_names="$(terraform_output_from_state "$state_file" frontend_release_alarm_names_csv)"
  backend_alarm_names="$(terraform_output_from_state "$state_file" backend_release_alarm_names_csv)"

  sync_env_var "$env_name" FRONTEND_RELEASE_ALARM_NAMES "$frontend_alarm_names"
  sync_env_var "$env_name" BACKEND_RELEASE_ALARM_NAMES "$backend_alarm_names"
}

sync_phase7_notification_vars() {
  local env_name="$1"
  local state_file="$2"
  local aws_region="$3"
  local notification_topic_arn
  local repo_topic_var
  local repo_region_var

  notification_topic_arn="$(terraform_output_from_state "$state_file" release_notifications_topic_arn)"

  sync_env_var "$env_name" RELEASE_NOTIFICATIONS_TOPIC_ARN "$notification_topic_arn"

  if [[ "$env_name" == "dev" ]]; then
    repo_topic_var="DEV_RELEASE_NOTIFICATIONS_TOPIC_ARN"
    repo_region_var="DEV_AWS_REGION"
  else
    repo_topic_var="PROD_RELEASE_NOTIFICATIONS_TOPIC_ARN"
    repo_region_var="PROD_AWS_REGION"
  fi

  # Repo-scoped variables are useful for notification jobs that intentionally run outside
  # an environment gate, such as approval-request emails before prod approval is granted.
  sync_repo_var "$repo_topic_var" "$notification_topic_arn"
  sync_repo_var "$repo_region_var" "$aws_region"
}

sync_network_runtime_defaults() {
  local env_name="$1"
  local frontend_subnets="$2"
  local backend_subnets="$3"
  local frontend_sg="$4"
  local backend_sg="$5"
  local service_launch_type="$6"
  local service_network_mode="$7"
  local service_assign_public_ip="$8"
  local probe_launch_type="$9"
  local probe_network_mode="${10}"
  local probe_assign_public_ip="${11}"
  local seeder_launch_type="${12}"
  local seeder_network_mode="${13}"
  local seeder_assign_public_ip="${14}"

  # These workflow-facing variables intentionally stay string-based because the
  # reusable workflows resolve subnet/security-group IDs later at runtime.
  sync_env_var "$env_name" SERVICE_LAUNCH_TYPE "$service_launch_type"
  sync_env_var "$env_name" SERVICE_NETWORK_MODE "$service_network_mode"
  sync_env_var "$env_name" SERVICE_SUBNET_TAG_VALUES "$backend_subnets"
  sync_env_var "$env_name" SERVICE_SECURITY_GROUP_NAME "$backend_sg"
  sync_env_var "$env_name" SERVICE_ASSIGN_PUBLIC_IP "$service_assign_public_ip"

  sync_env_var "$env_name" FRONTEND_SERVICE_SUBNET_TAG_VALUES "$frontend_subnets"
  sync_env_var "$env_name" BACKEND_SERVICE_SUBNET_TAG_VALUES "$backend_subnets"
  sync_env_var "$env_name" FRONTEND_SERVICE_SECURITY_GROUP_NAME "$frontend_sg"
  sync_env_var "$env_name" BACKEND_SERVICE_SECURITY_GROUP_NAME "$backend_sg"
  sync_env_var "$env_name" FRONTEND_SERVICE_ASSIGN_PUBLIC_IP "$service_assign_public_ip"
  sync_env_var "$env_name" BACKEND_SERVICE_ASSIGN_PUBLIC_IP "$service_assign_public_ip"

  # Probe usually validates the public-facing application path, so keep it on
  # the frontend-tier network boundary by default.
  sync_env_var "$env_name" PROBE_LAUNCH_TYPE "$probe_launch_type"
  sync_env_var "$env_name" PROBE_NETWORK_MODE "$probe_network_mode"
  sync_env_var "$env_name" PROBE_SUBNET_TAG_VALUES "$frontend_subnets"
  sync_env_var "$env_name" PROBE_SECURITY_GROUP_NAME "$frontend_sg"
  sync_env_var "$env_name" PROBE_ASSIGN_PUBLIC_IP "$probe_assign_public_ip"

  # Seeder usually follows backend/database adjacency, so keep it on the
  # backend-tier network boundary by default.
  sync_env_var "$env_name" SEEDER_LAUNCH_TYPE "$seeder_launch_type"
  sync_env_var "$env_name" SEEDER_NETWORK_MODE "$seeder_network_mode"
  sync_env_var "$env_name" SEEDER_SUBNET_TAG_VALUES "$backend_subnets"
  sync_env_var "$env_name" SEEDER_SECURITY_GROUP_NAME "$backend_sg"
  sync_env_var "$env_name" SEEDER_ASSIGN_PUBLIC_IP "$seeder_assign_public_ip"
}

run_for_environment() {
  local env_name="$1"
  local state_file
  local frontend_sg
  local backend_sg
  local aws_region
  local deployment_manifest_bucket

  case "$env_name" in
    dev)
      state_file="${ROOT_DIR}/state/dev.tfstate"
      frontend_sg="ecs-node-frontend-sg-dev"
      backend_sg="ecs-node-backend-sg-dev"
      aws_region="us-east-1"
      deployment_manifest_bucket="lirw-ecs-deployment-manifests-dev"
      ;;
    prod)
      state_file="${ROOT_DIR}/state/prod.tfstate"
      frontend_sg="ecs-node-frontend-sg-prod"
      backend_sg="ecs-node-backend-sg-prod"
      aws_region="us-east-2"
      deployment_manifest_bucket="lirw-ecs-deployment-manifests-prod"
      ;;
    *)
      echo "Error: unsupported environment '$env_name'."
      exit 1
      ;;
  esac

  if [[ ! -f "$state_file" ]]; then
    echo "Error: Terraform state file not found for $env_name: $state_file"
    echo "Run the environment apply first so telemetry alarm outputs exist."
    exit 1
  fi

  echo "======================================================"
  echo "Refreshing GitHub Environment variables for: $env_name"
  echo "Repository: $REPO"
  echo "Terraform state: $state_file"
  echo "Mode: $MODE"
  echo "Section: $ONLY_SECTION"
  echo "======================================================"

  if should_sync_section baseline; then
    sync_baseline_runtime_vars "$env_name" "$aws_region" "$deployment_manifest_bucket"
  fi

  if should_sync_section telemetry; then
    sync_phase3_telemetry_from_tf "$env_name" "$state_file"
  fi

  if should_sync_section notifications; then
    sync_phase7_notification_vars "$env_name" "$state_file" "$aws_region"
  fi

  if should_sync_section network; then
    sync_network_runtime_defaults \
      "$env_name" \
      "pri-sub-3a,pri-sub-4b" \
      "pri-sub-5a,pri-sub-6b" \
      "$frontend_sg" \
      "$backend_sg" \
      "EC2" \
      "non-awsvpc" \
      "DISABLED" \
      "FARGATE" \
      "awsvpc" \
      "ENABLED" \
      "EC2" \
      "non-awsvpc" \
      "DISABLED"
  fi

  echo "Completed refresh for $env_name."
  echo ""
}

if [[ "$TARGET_ENV" == "all" ]]; then
  run_for_environment dev
  run_for_environment prod
else
  run_for_environment "$TARGET_ENV"
fi
