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

git add .; git commit -m "host network specific changes made"; 
git push;
git tag tf-module-ec2-host 
git push origin tf-module-ec2-host

# git tag -l "lirw-*" | xargs -I {} git push origin --delete {}
# git tag -l "lirw-*" | xargs git tag -d

gh workflow run deploy.yml \
  --ref main \
  -f build_frontend=true \
  -f get_frontend=false \
  -f build_backend=true \
  -f get_backend=false \
  -f run_seeding=true

# gh run view 23976515430
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