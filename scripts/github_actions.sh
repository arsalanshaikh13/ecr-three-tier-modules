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

git add .; git commit -m "fargate specific changes made to the code adding 2 more subnets and changing rds subnets"; git push
git tag tf-module-fargate 
git push origin tf-module-fargate

git tag -l "lirw-*" | xargs -I {} git push origin --delete {}
git tag -l "circleci-*" | xargs -I {} git push origin --delete {}
git tag -l "lirw-*" | xargs git tag -d
git tag -l "circleci-*" | xargs git tag -d

# gh workflow run deploy.yml \
#   --ref main \
#   -f build_frontend=false \
#   -f get_frontend=false \
#   -f build_backend=false \
#   -f get_backend=false \
#   -f run_seeding=true

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