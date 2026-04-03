#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./gen_variables.sh path/to/main.tf [path/to/variables.tf]
# Example:
#   ./gen_variables.sh ./main.tf ./variables.tf

MAIN_TF="${1:-main.tf}"
VARS_TF="${2:-variables.tf}"

if [[ ! -f "$MAIN_TF" ]]; then
  echo "Error: $MAIN_TF not found"
  exit 1
fi

touch "$VARS_TF"

# Find var.<name> occurrences, dedupe, sorted
mapfile -t found_vars < <(
  grep -oE 'var\.[A-Za-z_][A-Za-z0-9_]*' "$MAIN_TF" \
  | sed 's/^var\.//' \
  | sort -u
)

if [[ ${#found_vars[@]} -eq 0 ]]; then
  echo "No var.<name> references found in $MAIN_TF"
  exit 0
fi

added=0
for v in "${found_vars[@]}"; do
  # Skip if variable already exists in variables.tf
  if grep -qE "^[[:space:]]*variable[[:space:]]+\"$v\"[[:space:]]*\{" "$VARS_TF"; then
    continue
  fi

  cat >> "$VARS_TF" <<EOF

variable "$v" {
  description = "Input variable for $v."
  type        = string
}
EOF
  ((added+=1))
done

echo "Found ${#found_vars[@]} variables in $MAIN_TF"
echo "Added $added new variable blocks to $VARS_TF"
