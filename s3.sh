#!/bin/bash
# s3://lirw-ecs-deployment-manifests-dev/lirw-ecs/deployments/dev/frontend/successful/

# aws s3api list-objects-v2 \
#     --bucket "lirw-ecs-deployment-manifests-dev" \
#     --prefix "lirw-ecs/deployments/dev/frontend/successful/" \
#     --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
#     --output text
# manifest=$(aws s3api list-objects-v2 \
#     --bucket "lirw-ecs-deployment-manifests-dev" \
#     --prefix "lirw-ecs/deployments/dev/frontend/successful/" \
#     --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
#     --output text)
# BUCKET="lirw-ecs-deployment-manifests-dev"
# PROJECT="lirw-ecs"
# SOURCE_ENV="dev"
# component="frontend"

# echo "manifest: $manifest";
# aws s3api list-objects-v2 \
#                             --bucket "$BUCKET" \
#                             --prefix "$PROJECT/deployments/$SOURCE_ENV/$component/successful/" \
#                             --query 'reverse(sort_by(Contents || `[]`, &LastModified))[0].Key' \
#                             --output text

aws ecs describe-tasks \
      --cluster "lirw-ecs-cluster-dev" \
      --tasks "arn:aws:ecs:us-east-1:750702272407:task/lirw-ecs-cluster-dev/92c58260c435486190870c6edb6ba86a" \
      --query "tasks[0].containers[0].logStreamName" \
      --output text


aws ecs describe-task-definition \
    --task-definition "arn:aws:ecs:us-east-1:750702272407:task-definition/lirw-ecs-probe-dev:10" \
    --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group"' \
    --output text
  
# Get container name
CONTAINER_NAME=$(aws ecs describe-tasks \
  --cluster "lirw-ecs-cluster-dev" \
  --tasks "arn:aws:ecs:us-east-1:750702272407:task/lirw-ecs-cluster-dev/92c58260c435486190870c6edb6ba86a" \
  --query "tasks[0].containers[0].name" \
  --output text)

# Extract task ID from ARN
TASK_ID="92c58260c435486190870c6edb6ba86a"

# Get stream prefix from task definition
STREAM_PREFIX=$(aws ecs describe-task-definition \
  --task-definition lirw-ecs-probe-dev:10 \
  --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-stream-prefix"' \
  --output text)

# Construct log stream name
LOG_STREAM_NAME="${STREAM_PREFIX}/${CONTAINER_NAME}/${TASK_ID}"
echo "log stream name: $LOG_STREAM_NAME"