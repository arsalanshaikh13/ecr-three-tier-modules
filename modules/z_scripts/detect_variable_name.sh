#!/usr/bin/env bash
set -euo pipefail

# detect_variables.sh
# Usage:
#   ./detect_variables.sh path/to/main.tf [path/to/variables.tf]
#
# Example:
#   ./detect_variables.sh ./main.tf ./variables.tf

MAIN_TF="${1:-main.tf}"
VARS_TF="${2:-variables.tf}"

if [[ ! -f "$MAIN_TF" ]]; then
  echo "Error: main file not found: $MAIN_TF" >&2
  exit 1
fi

touch "$VARS_TF"

make_description() {
  local v="$1"
  local pretty="${v//_/ }"
  pretty="$(echo "$pretty" | sed -E 's/(^| )pri( |$)/\1private\2/g; s/(^| )pub( |$)/\1public\2/g; s/(^| )sub( |$)/\1subnet\2/g; s/(^| )tg( |$)/\1target group\2/g; s/(^| )alb( |$)/\1application load balancer\2/g; s/(^| )([0-9]+)([ab])( |$)/\1\2 availability zone \3\4/g')"

  # Specific first
  case "$v" in
    *cidr*)            echo "CIDR block for ${pretty}."; return ;;
    *_subnet_ids|*subnet_ids) echo "List of subnet IDs for ${pretty}."; return ;;
    *_subnet_id|*subnet_id)   echo "Subnet ID for ${pretty}."; return ;;
    *_vpc_id|vpc_id)   echo "VPC ID for ${pretty}."; return ;;
    *_sg_id|*security_group_id) echo "Security group ID for ${pretty}."; return ;;
    *_zone_id|zone_id) echo "Hosted zone ID for ${pretty}."; return ;;
    *_listener_arn|*target_group_arn|*_arn|arn) echo "ARN for ${pretty}."; return ;;
    *_name|name)       echo "Name for ${pretty}."; return ;;
    *_domain|*_domain_name|domain_name) echo "Domain name for ${pretty}."; return ;;
    *health*check*path*|*health_check_path*|*hc_path*) echo "Health check path for ${pretty}."; return ;;
    *protocol*)         echo "Protocol for ${pretty}."; return ;;
    *_port|port)       echo "Port number for ${pretty}."; return ;;
    *lb_type*|*load_balancer_type*) echo "Load balancer type for ${pretty}."; return ;;
    *asg*_min_size|*_min_size|min_size|*asg*_min_cap|*_min_cap|min_cap) echo "Minimum Auto Scaling Group capacity for ${pretty}."; return ;;
    *asg*_max_size|*_max_size|max_size|*asg*_max_cap|*_max_cap|max_cap) echo "Maximum Auto Scaling Group capacity for ${pretty}."; return ;;
    *asg*_desired_capacity|*_desired_capacity|desired_capacity) echo "Desired Auto Scaling Group capacity for ${pretty}."; return ;;
    *_count|count|desired_count) echo "Count value for ${pretty}."; return ;;
    *instance_type*)   echo "EC2 instance type for ${pretty}."; return ;;
    *image_uri*|*image_url*) echo "Container image URI for ${pretty}."; return ;;
    *cpu*)             echo "CPU setting for ${pretty}."; return ;;
    *memory*)          echo "Memory setting for ${pretty}."; return ;;
    *region)           echo "AWS region for ${pretty}."; return ;;
    *environment|env|env_suffix) echo "Environment value for ${pretty}."; return ;;
    *project_name)     echo "Project name for ${pretty}."; return ;;
    *tags)             echo "Tags map for ${pretty}."; return ;;
    *password*|*secret*|*token*|*key*) echo "Sensitive value for ${pretty}."; return ;;
  esac

  # Generic suffix patterns
  case "$v" in
    *_id)   echo "ID of ${pretty% id}."; return ;;
    *_arn)  echo "ARN of ${pretty% arn}."; return ;;
  esac

  echo "Input variable for ${pretty}."
}

make_type() {
  local v="$1"

  case "$v" in
    *port*|*memory*|*cpu*|*size*|*cap*)
      echo "number"
      return
      ;;
  esac

  echo "string"
}

# Find var.<name> references in main.tf
mapfile -t vars < <(
  grep -oE 'var\.[A-Za-z_][A-Za-z0-9_]*' "$MAIN_TF" \
  | sed 's/^var\.//' \
  | sort -u
)

if [[ ${#vars[@]} -eq 0 ]]; then
  echo "No variables found in $MAIN_TF"
  exit 0
fi

added=0
skipped=0

for v in "${vars[@]}"; do
  if grep -qE "^[[:space:]]*variable[[:space:]]+\"$v\"[[:space:]]*\{" "$VARS_TF"; then
    ((skipped+=1))
    continue
  fi

  desc="$(make_description "$v")"
  var_type="$(make_type "$v")"

  cat >> "$VARS_TF" <<EOF

variable "$v" {
  description = "$desc"
  type        = $var_type
}
EOF

  ((added+=1))
done

echo "Scanned: $MAIN_TF"
echo "Found:   ${#vars[@]} variables"
echo "Added:   $added blocks to $VARS_TF"
echo "Skipped: $skipped existing blocks"
