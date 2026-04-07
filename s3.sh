#!/bin/bash
# s3://lirw-ecs-deployment-manifests-dev/lirw-ecs/deployments/dev/frontend/successful/

aws s3api list-objects-v2 \
    --bucket "lirw-ecs-deployment-manifests-dev" \
    --prefix "lirw-ecs/deployments/dev/frontend/successful/" \
    --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
    --output text
manifest=$(aws s3api list-objects-v2 \
    --bucket "lirw-ecs-deployment-manifests-dev" \
    --prefix "lirw-ecs/deployments/dev/frontend/successful/" \
    --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
    --output text)
BUCKET="lirw-ecs-deployment-manifests-dev"
PROJECT="lirw-ecs"
SOURCE_ENV="dev"
component="frontend"

echo "manifest: $manifest";
aws s3api list-objects-v2 \
                            --bucket "$BUCKET" \
                            --prefix "$PROJECT/deployments/$SOURCE_ENV/$component/successful/" \
                            --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
                            --output text