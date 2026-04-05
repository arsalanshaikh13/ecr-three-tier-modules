#!/bin/bash
# pwd
cd root
terraform init 

# terraform init -reconfigure

# exit 0

# terraform plan  -var-file=tfvars/prod.tfvars -state=./state/prod.tfstate
# terraform plan  -var-file=tfvars/dev.tfvars  -state=./state/dev.tfstate
terraform apply -var-file=tfvars/prod.tfvars -state=./state/prod.tfstate -parallelism=20 -auto-approve
#   
terraform apply -var-file=tfvars/dev.tfvars  -state=./state/dev.tfstate -parallelism=20 -auto-approve


# terraform apply -var-file=dev.tfvars -parallelism=20 -auto-approve
# terraform apply -var-file=prod.tfvars -parallelism=20 -auto-approve
