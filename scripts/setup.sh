#!/bin/bash
set -euo pipefail

TARGET="${1:-}"

if [[ "$TARGET" != "dev" && "$TARGET" != "prod" && "$TARGET" != "all" ]]; then
  echo "Usage: $0 <dev|prod|all>"
  exit 1
fi


apply_environment() {
  local environment="$1"
  local tfvars_file="tfvars/${environment}.tfvars"
  local state_file="./state/${environment}.tfstate"

  echo "Target environment: $environment"
  echo "Terraform var file: $tfvars_file"
  echo "Terraform state file: $state_file"
  echo ""

  # Keep each apply fully environment-scoped so dev and prod continue to use their own
  # tfvars and state files even when the caller asks for both in one run.
  # terraform plan -var-file="$tfvars_file" -state="$state_file"
  terraform apply -var-file="$tfvars_file" -state="$state_file" -parallelism=20 -auto-approve
  echo ""
}

cd root
terraform destroy -var-file=tfvars/dev.tfvars -state=state/dev.tfstate -target="module.lb.aws_lb_listener.backend_listener" -target="module.lb.aws_lb_listener.app_listener_https_secure" -auto-approve
terraform destroy -var-file=tfvars/prod.tfvars -state=state/prod.tfstate -target="module.lb.aws_lb_listener.backend_listener" -target="module.lb.aws_lb_listener.app_listener_https_secure" -auto-approve

terraform init

# terraform init -reconfigure
# terraform plan -var-file="tfvars/dev.tfvars" -state="./state/dev.tfstate"
# terraform plan -var-file="tfvars/prod.tfvars" -state="./state/prod.tfstate"
# terraform apply -var-file="tfvars/dev.tfvars" -state="./state/dev.tfstate" -target=module.asg.aws_appautoscaling_policy.ecs_policy_cpu -parallelism=20 -auto-approve

if [[ "$TARGET" == "all" ]]; then
  apply_environment dev
  apply_environment prod
else
  apply_environment "$TARGET"
fi
