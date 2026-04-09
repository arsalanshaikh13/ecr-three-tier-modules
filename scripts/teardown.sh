#!/bin/bash
set -euo pipefail

# ==========================================================
# Safely drain ECS services before Terraform destroy so the
# service-delete path does not spend unnecessary time waiting
# on task and target-group draining.
# ==========================================================

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <dev|prod|all>"
  echo "Error: ENV argument is required."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../root"
ENV_ARG="$1"

SERVICES=("backend-service" "frontend-service")
TARGET_GROUPS=("backend-internal-tg" "frontend-public-tg")

run_teardown() {
  local env_name="$1"
  local region
  local tfvars_file
  local state_file
  local cluster_name

  case "$env_name" in
    dev)
      region="us-east-1"
      tfvars_file="tfvars/dev.tfvars"
      state_file="./state/dev.tfstate"
      ;;
    prod)
      region="us-east-2"
      tfvars_file="tfvars/prod.tfvars"
      state_file="./state/prod.tfstate"
      ;;
    *)
      echo "Error: unsupported environment '$env_name'. Expected dev or prod."
      exit 1
      ;;
  esac

  cluster_name="lirw-ecs-cluster-${env_name}"

  echo "======================================================"
  echo "Initiating safe ECS teardown for: $env_name"
  echo "Cluster: $cluster_name"
  echo "Region: $region"
  echo "State: $state_file"
  echo "======================================================"

  cd "$ROOT_DIR"

  echo "1. Modifying target groups to drop connections immediately..."
  for tg_name in "${TARGET_GROUPS[@]}"; do
    echo "   Checking Target Group: $tg_name"

    tg_arn=$(aws elbv2 describe-target-groups \
      --names "$tg_name" \
      --region "$region" \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text 2>/dev/null || true)

    if [ -n "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
      aws elbv2 modify-target-group-attributes \
        --target-group-arn "$tg_arn" \
        --attributes Key=deregistration_delay.timeout_seconds,Value=0 \
        --region "$region" >/dev/null
      echo "      Deregistration delay set to 0."
    else
      echo "      Target group not found. Proceeding."
    fi
  done

  echo ""
  echo "2. Scaling ECS services down to 0..."
  for service_name in "${SERVICES[@]}"; do
    echo "   Scaling $service_name"
    if ! aws ecs update-service \
      --cluster "$cluster_name" \
      --service "$service_name" \
      --desired-count 0 \
      --region "$region" >/dev/null 2>&1; then
      echo "      Failed to update $service_name. It may already be gone."
    fi
  done

  echo ""
  echo "3. Force stopping any remaining ECS tasks..."
  for service_name in "${SERVICES[@]}"; do
    task_arns=$(aws ecs list-tasks \
      --cluster "$cluster_name" \
      --service-name "$service_name" \
      --desired-status RUNNING \
      --region "$region" \
      --query 'taskArns[]' \
      --output text 2>/dev/null || true)

    if [ -n "$task_arns" ] && [ "$task_arns" != "None" ]; then
      for task_arn in $task_arns; do
        echo "   Stopping task for $service_name: $task_arn"
        aws ecs stop-task \
          --cluster "$cluster_name" \
          --task "$task_arn" \
          --reason "Pre-terraform teardown cleanup" \
          --region "$region" >/dev/null 2>&1 || true
      done
    else
      echo "   No running tasks found for $service_name"
    fi
  done

  echo ""
  echo "4. Waiting for running tasks to stop..."
  while true; do
    all_services_down=true

    for service_name in "${SERVICES[@]}"; do
      running_tasks=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$region" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || true)

      if [[ ! "$running_tasks" =~ ^[0-9]+$ ]]; then
        running_tasks=0
      fi

      if [ "$running_tasks" -gt 0 ]; then
        echo "   $service_name still has $running_tasks task(s) running..."
        all_services_down=false
      fi
    done

    if [ "$all_services_down" = true ]; then
      echo "   All ECS tasks have stopped."
      break
    fi

    sleep 10
  done


  echo ""
  echo "6. Triggering Terraform destroy for $env_name..."
  terraform destroy \
    -var-file="$tfvars_file" \
    -state="$state_file" \
    -parallelism=20 \
    -auto-approve

  echo ""
  echo "Completed teardown for $env_name."
  echo "======================================================"
}

case "$ENV_ARG" in
  dev|prod)
    run_teardown "$ENV_ARG"
    ;;
  all)
    # Run sequentially so each environment keeps its own cluster, region, tfvars,
    # and state context instead of interleaving destroy operations.
    run_teardown dev
    run_teardown prod
    ;;
  *)
    echo "Usage: $0 <dev|prod|all>"
    echo "Error: unsupported environment '$ENV_ARG'."
    exit 1
    ;;
esac

