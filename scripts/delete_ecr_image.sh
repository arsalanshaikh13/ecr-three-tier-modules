#!/bin/bash

# Exit immediately if a pipeline fails
set -euo pipefail

# Keep the script explicit about environment because ECR repositories are split by
# both suffix and region. Making the caller choose dev or prod avoids accidentally
# deleting images from the wrong region with the right repository names.
ENVIRONMENT="${1:-}"

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Usage: $0 <dev|prod>"
  exit 1
fi

case "$ENVIRONMENT" in
  dev)
    AWS_REGION="us-east-1"
    ;;
  prod)
    AWS_REGION="us-east-2"
    ;;
esac

REPOS=(
  "lirw-ecs-database-seeder-repo-${ENVIRONMENT}"
  "lirw-ecs-backend-repo-${ENVIRONMENT}"
  "lirw-ecs-frontend-repo-${ENVIRONMENT}"
  "lirw-ecs-probe-repo-${ENVIRONMENT}"
)

echo "Target environment: $ENVIRONMENT"
echo "AWS region: $AWS_REGION"
echo ""

for REPO in "${REPOS[@]}"; do
  echo "========================================"
  echo "Checking repository: $REPO"
  echo "========================================"

  # Count how many images are in the repository
  IMAGE_COUNT=$(aws ecr list-images \
    --region "$AWS_REGION" \
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
  aws ecr list-images --region "$AWS_REGION" --repository-name "$REPO" \
    --query 'imageIds[*].imageDigest' --output text | \
    tr '\t' '\n' | \
    awk '{print "imageDigest="$1}' | \
    xargs -n 100 aws ecr batch-delete-image --region "$AWS_REGION" --repository-name "$REPO" --image-ids > /dev/null

  echo "Successfully deleted all images from $REPO."
  echo ""
done

echo "Done! All specified repositories for $ENVIRONMENT in $AWS_REGION have been emptied."
