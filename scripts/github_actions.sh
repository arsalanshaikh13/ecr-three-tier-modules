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

# pwd
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ROOT_DIR="${SCRIPT_DIR}/../.github/workflows/promotion.yml"
git add .; git commit -m "fixed sortby function issued in promotion.yml"
git push ;
# git tag tf-module-ec2-host-public
# git push origin tf-module-ec2-host-public

# git tag -l "lirw-*" | xargs -I {} git push origin --delete {}
# git tag -l "lirw-*" | xargs git tag -d

# Capture current time so we can identify the run we just triggered.
START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Fail immediately if GitHub cannot dispatch the workflow. If this returns HTTP 422
# while the branch file has workflow_dispatch, the default/main branch likely still
# has an older workflow definition registered by GitHub.
# if ! gh workflow run "promotion.yml" \
#   --ref multi-env-actions \
#   -f action_type=deploy \
#   -f target_environment=dev \
#   -f build_frontend=true \
#   -f get_frontend=false \
#   -f build_backend=true \
#   -f get_backend=false \
#   -f run_seeding=true; then
#   echo "Failed to dispatch deploy.yml."
#   echo "Check that the updated deploy.yml with workflow_dispatch exists on the default/main branch too."
#   exit 1
# fi

# curl -X POST \
#   -H "Authorization: token $(gh auth token)" \
#   -H "Accept: application/vnd.github.v3+json" \
#   https://api.github.com/repos//$GH_USER/$REPO_NAME/actions/workflows/deploy.yml/dispatches \
#   -d '{
#     "ref": "multi-env-actions",
#     "inputs": {
#       "action_type": "deploy",
#       "target_environment": "dev",
#       "build_frontend": "true",
#       "get_frontend": "false",
#       "build_backend": "true",
#       "get_backend": "false",
#       "run_seeding": "true"
#     }
#   }'


curl -X POST \
  -H "Authorization: token $(gh auth token)" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$GH_USER/$REPO_NAME/actions/workflows/promotion.yml/dispatches \
  -d '{
    "ref": "multi-env-actions",
    "inputs": {
      "source_environment": "dev",
      "promote_frontend": "true",
      "promote_backend": "true",
      "run_seeding_in_prod": "true"
    }
  }'
# # Small delay to allow GitHub to register the new run in run list.
# sleep 3

# # Fetch both internal run ID and human-readable run number for the latest dispatch after START_TS.
# RUN_ID=$(gh run list \
#   --repo "$GH_USER/$REPO_NAME" \
#   --workflow "promotion.yml" \
#   --branch multi-env-actions \
#   --event workflow_dispatch \
#   --limit 20 \
#   --json databaseId,number,createdAt \
#   --jq "map(select(.createdAt >= \"$START_TS\")) | first | .databaseId")

# RUN_NO=$(gh run list \
#   --repo "$GH_USER/$REPO_NAME" \
#   --workflow "promotion.yml" \
#   --branch multi-env-actions \
#   --event workflow_dispatch \
#   --limit 20 \
#   --json number,createdAt \
#   --jq "map(select(.createdAt >= \"$START_TS\")) | first | .number")

# echo "Triggered deploy workflow: RUN_ID=$RUN_ID RUN_NO=$RUN_NO"
# if [ -z "$RUN_ID" ] || [ "$RUN_ID" = "null" ]; then
#   echo "Failed to resolve the dispatched run id."
#   exit 1
# fi

# gh run view "$RUN_ID" --repo "$GH_USER/$REPO_NAME"

# # one line trigger
# gh run list --repo "$GH_USER/$REPO_NAME" --workflow "promotion.yml" --branch multi-env-actions --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'
gh run list --repo "$GH_USER/$REPO_NAME" --workflow "promotion.yml" --branch multi-env-actions --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'

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
