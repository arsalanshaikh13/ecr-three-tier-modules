#!/bin/bash
set -euo pipefail

# ==========================================================
# Recover Terraform state for resources that were created in AWS
# before Terraform had a chance to persist them locally.
# ==========================================================

# Guardrail: these errors were for prod resources, so defaulting silently would be risky.
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <prod>"
  echo "Error: ENV argument is required."
  exit 1
fi
ENV="$1"
cd root

if [ "$ENV" != "prod" ]; then
  echo "Error: this import helper currently targets only prod resources."
  echo "Reason: the failed resources in the last apply were prod-only:"
  echo "  - lirw-ecs-db-prod"
  echo "  - prod.devsandbox.space"
  echo "  - api-prod.devsandbox.space"
  exit 1
fi

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ROOT_DIR="${SCRIPT_DIR}/../root"

# cd "$ROOT_DIR"

# These imports belong in prod state because the existing AWS resources are prod-scoped.
STATE_FILE="./state/prod.tfstate"

echo "======================================================"
echo "Recovering Terraform state for interrupted prod apply"
echo "State file: $STATE_FILE"
echo "======================================================"

echo "1. Resolving Route53 hosted zone ID for devsandbox.space..."
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "devsandbox.space" \
  --query "HostedZones[0].Id" \
  --output text)
ZONE_ID="${ZONE_ID##*/}"

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
  echo "Error: could not resolve hosted zone ID for devsandbox.space"
  exit 1
fi

echo "Hosted zone ID: $ZONE_ID"

# echo "2. Importing RDS subnet group first in case it was created before the instance..."
# terraform import -var-file=tfvars/prod.tfvars -state="$STATE_FILE"  \
#   'module.rds.aws_db_subnet_group.main' \
#   'rds-subnet-group-prod' || true

echo "3. Importing RDS instance..."
terraform import -var-file=tfvars/prod.tfvars -state="$STATE_FILE" \
  'module.rds.aws_db_instance.mysql_db' \
  'lirw-ecs-db-prod'

echo "4. Importing frontend Route53 alias record..."
terraform import -var-file=tfvars/prod.tfvars -state="$STATE_FILE" \
  'module.route53.aws_route53_record.env_alias' \
  "${ZONE_ID}_prod.devsandbox.space_A"

echo "5. Importing API Route53 alias record..."
terraform import -var-file=tfvars/prod.tfvars -state="$STATE_FILE" \
  'module.route53.aws_route53_record.api_alias' \
  "${ZONE_ID}_api-prod.devsandbox.space_A"

echo "6. Current imported resources in prod state:"
terraform state list -state="$STATE_FILE"
terraform state list -state="$STATE_FILE" | wc -l

echo "======================================================"
echo "Imports completed. Next step:"
echo "terraform plan -state=$STATE_FILE -var-file=./tfvars/prod.tfvars"
echo "======================================================"
