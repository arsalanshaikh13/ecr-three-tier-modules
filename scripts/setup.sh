#!/bin/bash
# pwd
cd root
# terraform plan -var-file=dev.tfvars
# terraform plan -var-file=dev.tfvars 
terraform apply -var-file=dev.tfvars -parallelism=20 -auto-approve