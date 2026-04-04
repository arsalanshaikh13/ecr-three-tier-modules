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

git add .; git commit -m "imported bridge module for sg and made bridge mode change in dev.tfvars"; 
git push;
# git tag tf-module-ec2-bridge-private
# git push origin tf-module-ec2-bridge-private

# git tag -l "lirw-*" | xargs -I {} git push origin --delete {}
# git tag -l "lirw-*" | xargs git tag -d

# Capture current time so we can identify the run we just triggered.
START_TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

gh workflow run deploy.yml \
  --ref main \
  -f build_frontend=false \
  -f get_frontend=false \
  -f build_backend=false \
  -f get_backend=false \
  -f run_seeding=true

# Small delay to allow GitHub to register the new run in run list.
sleep 3

# Fetch both internal run ID and human-readable run number for the latest dispatch after START_TS.
RUN_ID=$(gh run list \
  --workflow deploy.yml \
  --branch main \
  --event workflow_dispatch \
  --limit 20 \
  --json databaseId,number,createdAt \
  --jq "map(select(.createdAt >= \"$START_TS\")) | first | .databaseId")

RUN_NO=$(gh run list \
  --workflow deploy.yml \
  --branch main \
  --event workflow_dispatch \
  --limit 20 \
  --json number,createdAt \
  --jq "map(select(.createdAt >= \"$START_TS\")) | first | .number")

echo "Triggered deploy workflow: RUN_ID=$RUN_ID RUN_NO=$RUN_NO"
gh run view "$RUN_ID"

# one line trigger
gh run list --workflow deploy.yml --branch main --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId'

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
