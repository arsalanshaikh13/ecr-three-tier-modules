#!/bin/bash
# git add .; git commit -m "host network specific changes made";
# git tag nextjs-host; 
# git checkout head^
# git tag nextjs-bridge;
# git push origin --tags;
# git checkout -b nextjs-fargate
# git checkout main
# git checkout -b service-discovery
# git checkout nextjs-fargate

GH_USER="arsalanshaikh13"
REPO_NAME="ecr-three-tier-modules"

# 3. Create 'production' Environment & Secrets
# echo "Creating production env..."
# gh api --method PUT "repos/$GH_USER/$REPO_NAME/environments/prod"
# gh api --method PUT "repos/$GH_USER/$REPO_NAME/environments/dev"

# # set variables and secrets in environment

# gh variable set ENV_VAR --body "dev" --repo "$GH_USER/$REPO_NAME" --env dev
# gh variable set ACCOUNT_ID --body "750702272407" --repo "$GH_USER/$REPO_NAME" --env dev
# gh variable set PROJECT_NAME --body "lirw-ecs" --repo "$GH_USER/$REPO_NAME" --env dev
# gh variable set AWS_REGION --body "us-east-1" --repo "$GH_USER/$REPO_NAME" --env dev
# gh variable set DEPLOYMENT_MANIFEST_BUCKET --body "lirw-ecs-deployment-manifests-dev" --repo "$GH_USER/$REPO_NAME" --env dev
# gh variable set ENV_VAR --body "prod" --repo "$GH_USER/$REPO_NAME" --env prod
# gh variable set ACCOUNT_ID --body "750702272407" --repo "$GH_USER/$REPO_NAME" --env prod
# gh variable set PROJECT_NAME --body "lirw-ecs" --repo "$GH_USER/$REPO_NAME" --env prod
# gh variable set AWS_REGION --body "us-east-2" --repo "$GH_USER/$REPO_NAME" --env prod
# gh variable set DEPLOYMENT_MANIFEST_BUCKET --body "lirw-ecs-deployment-manifests-prod" --repo "$GH_USER/$REPO_NAME" --env prod

# ---------------------------------------------------------------------------
# Environment Variable Bootstrap For Dev / Prod
# ---------------------------------------------------------------------------
# This block keeps GitHub Environment variable setup next to the rest of the
# workflow automation. The new component-aware service subnet variables let the
# deploy and rollback workflows target different private subnet groups for the
# frontend and backend tiers without changing the reusable actions.
#
# Frontend private subnets:
# - pri-sub-3a
# - pri-sub-4b
#
# Backend private subnets:
# - pri-sub-5a
# - pri-sub-6b
#
# Uncomment and run when you want to create or refresh the environment vars.

# set_env_var() {
#   local env_name="$1"
#   local var_name="$2"
#   local var_value="$3"
#
#   gh variable set "$var_name" \
#     --repo "$GH_USER/$REPO_NAME" \
#     --env "$env_name" \
#     --body "$var_value"
# }
#
# # -----------------------------
# # Required baseline variables
# # -----------------------------
# set_env_var dev  ENV_VAR "dev"
# set_env_var dev  ACCOUNT_ID "750702272407"
# set_env_var dev  PROJECT_NAME "lirw-ecs"
# set_env_var dev  AWS_REGION "us-east-1"
# set_env_var dev  DEPLOYMENT_MANIFEST_BUCKET "lirw-ecs-deployment-manifests-dev"
# set_env_var dev  DEPLOYMENT_MANIFEST_BUCKET_PREFIX "lirw-ecs-deployment-manifests"
#
# set_env_var prod ENV_VAR "prod"
# set_env_var prod ACCOUNT_ID "750702272407"
# set_env_var prod PROJECT_NAME "lirw-ecs"
# set_env_var prod AWS_REGION "us-east-2"
# set_env_var prod DEPLOYMENT_MANIFEST_BUCKET "lirw-ecs-deployment-manifests-prod"
# set_env_var prod DEPLOYMENT_MANIFEST_BUCKET_PREFIX "lirw-ecs-deployment-manifests"
#
# # ---------------------------------------------------------
# # Required component-aware service networking variables
# # ---------------------------------------------------------
# # These are the new variables introduced by the subnet split patch.
# # The workflows will prefer these over the older shared SERVICE_* vars.
# set_env_var dev  FRONTEND_SERVICE_SUBNET_TAG_VALUES "pri-sub-3a,pri-sub-4b"
# set_env_var dev  BACKEND_SERVICE_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var dev  FRONTEND_SERVICE_SECURITY_GROUP_NAME "ecs-node-frontend-sg-dev"
# set_env_var dev  BACKEND_SERVICE_SECURITY_GROUP_NAME "ecs-node-backend-sg-dev"
# set_env_var dev  FRONTEND_SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
# set_env_var dev  BACKEND_SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
#
# set_env_var prod FRONTEND_SERVICE_SUBNET_TAG_VALUES "pri-sub-3a,pri-sub-4b"
# set_env_var prod BACKEND_SERVICE_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var prod FRONTEND_SERVICE_SECURITY_GROUP_NAME "ecs-node-frontend-sg-prod"
# set_env_var prod BACKEND_SERVICE_SECURITY_GROUP_NAME "ecs-node-backend-sg-prod"
# set_env_var prod FRONTEND_SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
# set_env_var prod BACKEND_SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
#
# # ----------------------------------------------------------------
# # Recommended shared/default service variables for compatibility
# # ----------------------------------------------------------------
# # Keep these while migrating so older fallback paths still behave predictably.
# # They also document the default runtime shape for service-style ECS operations.
# set_env_var dev  SERVICE_LAUNCH_TYPE "EC2"
# set_env_var dev  SERVICE_NETWORK_MODE "non-awsvpc"
# set_env_var dev  SERVICE_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var dev  SERVICE_SECURITY_GROUP_NAME "ecs-node-backend-sg-dev"
# set_env_var dev  SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
#
# set_env_var prod SERVICE_LAUNCH_TYPE "EC2"
# set_env_var prod SERVICE_NETWORK_MODE "non-awsvpc"
# set_env_var prod SERVICE_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var prod SERVICE_SECURITY_GROUP_NAME "ecs-node-backend-sg-prod"
# set_env_var prod SERVICE_ASSIGN_PUBLIC_IP "DISABLED"
#
# # -----------------------------------------------------
# # Recommended probe execution variables
# # -----------------------------------------------------
# # Probe remains intentionally separate from service deploy networking.
# # Keep probe on the fast Fargate/awsvpc path unless you are testing otherwise.
# set_env_var dev  PROBE_LAUNCH_TYPE "FARGATE"
# set_env_var dev  PROBE_NETWORK_MODE "awsvpc"
# set_env_var dev  PROBE_SUBNET_TAG_VALUES "pri-sub-3a,pri-sub-4b"
# set_env_var dev  PROBE_SECURITY_GROUP_NAME "ecs-node-frontend-sg-dev"
# set_env_var dev  PROBE_ASSIGN_PUBLIC_IP "ENABLED"
#
# set_env_var prod PROBE_LAUNCH_TYPE "FARGATE"
# set_env_var prod PROBE_NETWORK_MODE "awsvpc"
# set_env_var prod PROBE_SUBNET_TAG_VALUES "pri-sub-3a,pri-sub-4b"
# set_env_var prod PROBE_SECURITY_GROUP_NAME "ecs-node-frontend-sg-prod"
# set_env_var prod PROBE_ASSIGN_PUBLIC_IP "ENABLED"
#
# # -----------------------------------------------------
# # Recommended database seeder variables
# # -----------------------------------------------------
# # Seeder normally follows backend-style private network placement because it
# # talks to the database tier rather than serving public traffic.
# set_env_var dev  SEEDER_LAUNCH_TYPE "EC2"
# set_env_var dev  SEEDER_NETWORK_MODE "non-awsvpc"
# set_env_var dev  SEEDER_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var dev  SEEDER_SECURITY_GROUP_NAME "ecs-node-backend-sg-dev"
# set_env_var dev  SEEDER_ASSIGN_PUBLIC_IP "DISABLED"
#
# set_env_var prod SEEDER_LAUNCH_TYPE "EC2"
# set_env_var prod SEEDER_NETWORK_MODE "non-awsvpc"
# set_env_var prod SEEDER_SUBNET_TAG_VALUES "pri-sub-5a,pri-sub-6b"
# set_env_var prod SEEDER_SECURITY_GROUP_NAME "ecs-node-backend-sg-prod"
# set_env_var prod SEEDER_ASSIGN_PUBLIC_IP "DISABLED"
#
# # -----------------------------------------
# # Optional prod governance variables
# # -----------------------------------------
# # Guardrail workflows read this only when you want prod freeze windows enforced.
# # Example format is workflow-specific, so keep it empty until you are ready.
# # set_env_var prod PROD_FREEZE_WINDOWS_UTC ""
#
# # -----------------------------------------------------
# # Phase 3 telemetry-gate variables
# # -----------------------------------------------------
# # The deploy workflow now supports a CloudWatch-based release-health gate.
# # These environment variables tell GitHub Actions which alarms belong to the
# # frontend and backend release checks for each environment.
# #
# # Recommended flow:
# # 1. apply Terraform
# # 2. read the CSV outputs:
# #    - frontend_release_alarm_names_csv
# #    - backend_release_alarm_names_csv
# # 3. write those values into GitHub Environment variables below
# #
# # You can set them manually if you already know the alarm names:
# # set_env_var dev  FRONTEND_RELEASE_ALARM_NAMES "lirw-ecs-frontend-dev-target-5xx,lirw-ecs-frontend-dev-latency,lirw-ecs-frontend-dev-cpu-high,lirw-ecs-frontend-dev-memory-high"
# # set_env_var dev  BACKEND_RELEASE_ALARM_NAMES "lirw-ecs-backend-dev-target-5xx,lirw-ecs-backend-dev-latency,lirw-ecs-backend-dev-cpu-high,lirw-ecs-backend-dev-memory-high"
# # set_env_var prod FRONTEND_RELEASE_ALARM_NAMES "lirw-ecs-frontend-prod-target-5xx,lirw-ecs-frontend-prod-latency,lirw-ecs-frontend-prod-cpu-high,lirw-ecs-frontend-prod-memory-high"
# # set_env_var prod BACKEND_RELEASE_ALARM_NAMES "lirw-ecs-backend-prod-target-5xx,lirw-ecs-backend-prod-latency,lirw-ecs-backend-prod-cpu-high,lirw-ecs-backend-prod-memory-high"
# #
# # Or derive them from Terraform outputs after each environment apply:
# # DEV_FRONTEND_RELEASE_ALARMS="$(terraform -chdir=root output -raw frontend_release_alarm_names_csv)"
# # DEV_BACKEND_RELEASE_ALARMS="$(terraform -chdir=root output -raw backend_release_alarm_names_csv)"
# # set_env_var dev FRONTEND_RELEASE_ALARM_NAMES "$DEV_FRONTEND_RELEASE_ALARMS"
# # set_env_var dev BACKEND_RELEASE_ALARM_NAMES "$DEV_BACKEND_RELEASE_ALARMS"
# #
# # For prod, run the same command after applying the prod tfvars-backed stack:
# # PROD_FRONTEND_RELEASE_ALARMS="$(terraform -chdir=root output -raw frontend_release_alarm_names_csv)"
# # PROD_BACKEND_RELEASE_ALARMS="$(terraform -chdir=root output -raw backend_release_alarm_names_csv)"
# # set_env_var prod FRONTEND_RELEASE_ALARM_NAMES "$PROD_FRONTEND_RELEASE_ALARMS"
# # set_env_var prod BACKEND_RELEASE_ALARM_NAMES "$PROD_BACKEND_RELEASE_ALARMS"
#
# # Optional policy toggle examples for testing:
# # gh workflow run deploy.yml --ref multi-env-actions -f enable_telemetry_gate=true -f observation_window_minutes=5
#
# # Quick verification
# # gh variable list --repo "$GH_USER/$REPO_NAME" --env dev
# # gh variable list --repo "$GH_USER/$REPO_NAME" --env prod

# pwd
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ROOT_DIR="${SCRIPT_DIR}/../.github/workflows/deploy.yml"
# git status
# git add .; 
# # # git commit -m "for switching both dev and prod to FARGATE "
# git commit -m "fargate mode specific changes made in ecs_fargate, efs, lb both environment "
# git push   ;
# git tag host-mode-workflow
# git push origin host-mode-workflow

# git tag -l "lirw-*" | xargs -I {} git push origin --delete {}
# git tag -l "lirw-*" | xargs git tag -d

# Capture current time so we can identify the run we just triggered.
START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Fail immediately if GitHub cannot dispatch the workflow. If this returns HTTP 422
# while the branch file has workflow_dispatch, the default/main branch likely still
# has an older workflow definition registered by GitHub.
# if ! gh workflow run "deploy.yml" \
#   --ref multi-env-actions \
#   -f action_type=rollback \
#   -f target_environment=dev \
#   -f build_frontend=true \
#   -f get_frontend=false \
#   -f build_backend=true \
#   -f get_backend=false \
#   -f run_seeding=true \
#   -f default_network_mode=awsvpc \
#   -f default_launch_type=FARGATE; then
#   echo "Failed to dispatch deploy.yml."
#   echo "Check that the updated deploy.yml with workflow_dispatch exists on the default/main branch too."
#   exit 1
# fi

# curl --fail-with-body -X POST \
#   -H "Authorization: token $(gh auth token)" \
#   -H "Accept: application/vnd.github.v3+json" \
#   "https://api.github.com/repos/$GH_USER/$REPO_NAME/actions/workflows/deploy.yml/dispatches" \
#   -d '{
#     "ref": "multi-env-actions",
#     "inputs": {
#       "action_type": "deploy",
#       "target_environment": "dev",
#       "build_frontend": "true",
#       "get_frontend": "false",
#       "build_backend": "true",
#       "get_backend": "false",
#       "run_seeding": "true".
        # "default_network_mode": "non-awsvpc",
        # "default_launch_type": "EC2"
#     }
#   }'


# curl --fail-with-body -X POST \
#   -H "Authorization: token $(gh auth token)" \
#   -H "Accept: application/vnd.github.v3+json" \
#   https://api.github.com/repos/$GH_USER/$REPO_NAME/actions/workflows/promotion.yml/dispatches \
#   -d '{
#     "ref": "multi-env-actions",
#     "inputs": {
#       "source_environment": "dev",
#       "promote_frontend": "true",
#       "promote_backend": "true",
#       "run_seeding_in_prod": "false",
#       "default_network_mode": "non-awsvpc",
#       "default_launch_type": "EC2"
#     }
#   }'
# Small delay to allow GitHub to register the new run in run list.
# sleep 3

# # Fetch both internal run ID and human-readable run number for the latest dispatch after START_TS.
# RUN_ID=$(gh run list \
#   --repo "$GH_USER/$REPO_NAME" \
#   --workflow "deploy.yml" \
#   --branch multi-env-actions \
#   --event workflow_dispatch \
#   --limit 20 \
#   --json databaseId,number,createdAt \
#   --jq "map(select(.createdAt >= \"$START_TS\")) | first | .databaseId")

# RUN_NO=$(gh run list \
#   --repo "$GH_USER/$REPO_NAME" \
#   --workflow "deploy.yml" \
#   --branch multi-env-actions \
#   --event workflow_dispatch \
#   --limit 20 \
#   --json number,createdAt \
#   --jq "map(select(.createdAt >= \"$START_TS\")) | first | .number")

echo "Triggered deploy workflow: RUN_ID=$RUN_ID RUN_NO=$RUN_NO"
if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
  echo "Failed to resolve the dispatched run id."
  exit 1
fi

gh run view "$RUN_ID" --repo "$GH_USER/$REPO_NAME"

# one line trigger
gh run list --repo "$GH_USER/$REPO_NAME" --workflow "deploy.yml" --branch multi-env-actions --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
# gh run list --repo "$GH_USER/$REPO_NAME" --workflow "deploy.yml" --branch multi-env-actions --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'

#   # Variables
# ORG="arsalanshaikh13"
# REPO="ecr-three-tier"
# WORKFLOW_ID="../.github/workflows/deploy.yml" # You can also use the numeric ID

# curl -L \
#   -X POST \
#   -H "Accept: application/vnd.github+json" \
#   -H "Authorization: Bearer $GITHUB_TOKEN" \
#   -H "X-GitHub-Api-Version: 2022-11-28" \
#   https://api.github.com/repos/$ORG/$REPO/actions/workflows/$WORKFLOW_ID/dispatches \
#   -d '{
#     "ref": "main",
#     "inputs": {
#       "build_frontend": "true",
#       "get_frontend": "false",
#       "build_backend": "true",
#       "get_backend": "false",
#       "run_seeding": "false"
#     }
#   }'

# -----------------------------------------------------------------------------
# Prod Approval Environment Setup
# -----------------------------------------------------------------------------
# GitHub environment approval rules are configured through the Environments API,
# not directly in workflow YAML. The workflows only bind jobs to an environment
# such as `prod-approval` or `prod`.

# For your current use case:
# - `prod-approval` should hold the reviewer gate
# - `prod` should hold execution vars/secrets
# - because you are the only user and want to simulate approval yourself,
#   keep `prevent_self_review=false`

# Branch guardrail note:
# - GitHub environment branch policy can restrict which branches may deploy to
#   an environment
# - tag-specific approval restriction is not first-class in the same simple way,
#   so the practical guardrail here is branch restriction plus workflow inputs

# Example branch to allow through prod approval:
APPROVAL_BRANCH="multi-env-actions"

# Resolve your GitHub user id once so required reviewers can be updated through API.
APPROVER_USER="$GH_USER"
APPROVER_USER_ID=$(gh api "/users/$APPROVER_USER" --jq '.id')

# Create or update the dedicated approval environment.
# Keep required reviewers here, not on `prod`, if you want only one approval gate.
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$GH_USER/$REPO_NAME/environments/prod-approval" \
  -f wait_timer=0 \
  -F prevent_self_review=false \
  -F deployment_branch_policy[protected_branches]=false \
  -F deployment_branch_policy[custom_branch_policies]=true \
  -f reviewers[0][type]=User \
  -F reviewers[0][id]="$APPROVER_USER_ID"

# Restrict prod-approval to the branch you use for controlled promotion tests.
# GitHub models branch policies as deployment branch policies attached to the environment.
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/$GH_USER/$REPO_NAME/environments/prod-approval/deployment-branch-policies" \
  -f name="$APPROVAL_BRANCH"

# Create or update the execution environment separately.
# Recommendation: keep vars/secrets here, but do not also require reviewers if you want
# the human approval to happen only once on `prod-approval`.
# gh api \
#   --method PUT \
#   -H "Accept: application/vnd.github+json" \
#   "/repos/$GH_USER/$REPO_NAME/environments/prod" \
#   -f wait_timer=0 \
#   -F prevent_self_review=false \
#   -F deployment_branch_policy[protected_branches]=false \
#   -F deployment_branch_policy[custom_branch_policies]=false

# Optional: inspect the configured environments after setup.
gh api "/repos/$GH_USER/$REPO_NAME/environments"

# -----------------------------------------------------------------------------
# Terraform Output -> GitHub Environment Variable Sync Helpers
# -----------------------------------------------------------------------------
# This block is intentionally separate from the earlier bootstrap examples.
# It is meant for the "refresh from Terraform outputs" workflow after you run
# environment-specific applies. Keep it append-only so it can be enabled or
# disabled without disturbing the hand-authored setup notes above.
#
# Design decision:
# - GitHub Actions should consume stable environment variables
# - Terraform should remain the source of truth for environment-specific runtime
#   identifiers when those identifiers are derived from provisioned resources
# - this helper bridges the two without hardcoding values into workflow YAML
#
# Expected usage:
# 1. apply the target environment infrastructure
# 2. run terraform output for the relevant values
# 3. write the values into the matching GitHub Environment variables
#
# Notes:
# - alarm outputs already exist in root/outputs.tf
# - subnet/security-group values are still often known from naming/tagging
#   conventions, so the examples below support both terraform-driven and manual
#   fallback assignment

# sync_env_var() {
#   local env_name="$1"
#   local var_name="$2"
#   local var_value="$3"
#
#   gh variable set "$var_name" \
#     --repo "$GH_USER/$REPO_NAME" \
#     --env "$env_name" \
#     --body "$var_value"
# }
#
# sync_phase3_telemetry_from_tf() {
#   local env_name="$1"
#   local tf_dir="$2"
#
#   local frontend_alarm_names
#   local backend_alarm_names
#
#   frontend_alarm_names="$(terraform -chdir="$tf_dir" output -raw frontend_release_alarm_names_csv)"
#   backend_alarm_names="$(terraform -chdir="$tf_dir" output -raw backend_release_alarm_names_csv)"
#
#   sync_env_var "$env_name" FRONTEND_RELEASE_ALARM_NAMES "$frontend_alarm_names"
#   sync_env_var "$env_name" BACKEND_RELEASE_ALARM_NAMES "$backend_alarm_names"
# }
#
# # -------------------------------------------------------------------------
# # Telemetry gate sync from Terraform outputs
# # -------------------------------------------------------------------------
# # Example:
# # sync_phase3_telemetry_from_tf dev  root
# # sync_phase3_telemetry_from_tf prod root
#
# sync_network_runtime_defaults() {
#   local env_name="$1"
#   local frontend_subnets="$2"
#   local backend_subnets="$3"
#   local frontend_sg="$4"
#   local backend_sg="$5"
#   local probe_subnets="$6"
#   local probe_sg="$7"
#   local seeder_subnets="$8"
#   local seeder_sg="$9"
#
#   # Service deploy/rollback path variables
#   sync_env_var "$env_name" FRONTEND_SERVICE_SUBNET_TAG_VALUES "$frontend_subnets"
#   sync_env_var "$env_name" BACKEND_SERVICE_SUBNET_TAG_VALUES "$backend_subnets"
#   sync_env_var "$env_name" FRONTEND_SERVICE_SECURITY_GROUP_NAME "$frontend_sg"
#   sync_env_var "$env_name" BACKEND_SERVICE_SECURITY_GROUP_NAME "$backend_sg"
#
#   # Probe runtime variables
#   sync_env_var "$env_name" PROBE_SUBNET_TAG_VALUES "$probe_subnets"
#   sync_env_var "$env_name" PROBE_SECURITY_GROUP_NAME "$probe_sg"
#
#   # Seeder runtime variables
#   sync_env_var "$env_name" SEEDER_SUBNET_TAG_VALUES "$seeder_subnets"
#   sync_env_var "$env_name" SEEDER_SECURITY_GROUP_NAME "$seeder_sg"
# }
#
# # -------------------------------------------------------------------------
# # Subnet / security-group sync
# # -------------------------------------------------------------------------
# # Use this helper when the values are convention-driven and already known.
# # It keeps the workflow-facing variables aligned with the three-tier subnet
# # design without having to edit YAML when the runtime topology changes.
# #
# # Current known conventions in this repo:
# # - frontend private subnets: pri-sub-3a,pri-sub-4b
# # - backend private subnets:  pri-sub-5a,pri-sub-6b
# # - probe usually follows frontend-facing network placement
# # - seeder usually follows backend-facing network placement
# #
# # Example for dev:
# # sync_network_runtime_defaults \
# #   dev \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-frontend-sg-dev" \
# #   "ecs-node-backend-sg-dev" \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "ecs-node-frontend-sg-dev" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-backend-sg-dev"
# #
# # Example for prod:
# # sync_network_runtime_defaults \
# #   prod \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-frontend-sg-prod" \
# #   "ecs-node-backend-sg-prod" \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "ecs-node-frontend-sg-prod" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-backend-sg-prod"
#
# # -------------------------------------------------------------------------
# # Combined refresh examples
# # -------------------------------------------------------------------------
# # sync_phase3_telemetry_from_tf dev root
# # sync_network_runtime_defaults \
# #   dev \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-frontend-sg-dev" \
# #   "ecs-node-backend-sg-dev" \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "ecs-node-frontend-sg-dev" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-backend-sg-dev"
#
# # sync_phase3_telemetry_from_tf prod root
# # sync_network_runtime_defaults \
# #   prod \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-frontend-sg-prod" \
# #   "ecs-node-backend-sg-prod" \
# #   "pri-sub-3a,pri-sub-4b" \
# #   "ecs-node-frontend-sg-prod" \
# #   "pri-sub-5a,pri-sub-6b" \
# #   "ecs-node-backend-sg-prod"
