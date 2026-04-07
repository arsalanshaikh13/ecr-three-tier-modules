#!/bin/bash

# Exit immediately if a pipeline fails
set -euo pipefail

# Define the list of repositories
REPOS=(
  "lirw-ecs-database-seeder-repo-dev"
  "lirw-ecs-backend-repo-dev"
  "lirw-ecs-frontend-repo-dev"
  "lirw-ecs-probe-repo-dev"
)

for REPO in "${REPOS[@]}"; do
  echo "========================================"
  echo "Checking repository: $REPO"
  echo "========================================"

  # Count how many images are in the repository
  IMAGE_COUNT=$(aws ecr list-images \
    --repository-name "$REPO" \
    --query 'length(imageIds)' \
    --output text 2>/dev/null || echo "0")

  if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "Repository is already empty or does not exist. Skipping..."
    echo ""
    continue
  fi

  echo "Found $IMAGE_COUNT images. Deleting in batches of 100..."

  # Fetch digests, format them, and delete in batches
  aws ecr list-images --repository-name "$REPO" \
    --query 'imageIds[*].imageDigest' --output text | \
    tr '\t' '\n' | \
    awk '{print "imageDigest="$1}' | \
    xargs -n 100 aws ecr batch-delete-image --repository-name "$REPO" --image-ids > /dev/null

  echo "Successfully deleted all images from $REPO."
  echo ""
done

echo "Done! All specified repositories have been emptied."