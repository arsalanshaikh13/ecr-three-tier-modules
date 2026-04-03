#!/usr/bin/env bash
set -euo pipefail

# generate_modules.sh
# Run this from: ecr-three-tier-modules/
#
# Usage:
#   ./generate_modules.sh                # print blocks to stdout
#   ./generate_modules.sh > modules.auto.generated.tf
#   ./generate_modules.sh --write main.generated.tf

MODULES_DIR="${1:-modules}"
WRITE_FILE=""

if [[ "${1:-}" == "--write" ]]; then
  WRITE_FILE="${2:?Provide output file path after --write}"
  MODULES_DIR="modules"
fi

if [[ ! -d "$MODULES_DIR" ]]; then
  echo "Error: directory not found: $MODULES_DIR" >&2
  exit 1
fi

generate() {
  # Only immediate child folders, sorted
  find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort | while read -r folder; do
    # Skip utility folders if needed
    case "$folder" in
      z_scripts|scripts|.git) continue ;;
    esac

    # Terraform module label should be identifier-safe
    module_name="$(echo "$folder" | sed 's/[^A-Za-z0-9_]/_/g')"

    cat <<EOF
module "$module_name" {
  source = "../modules/$folder"

  # TODO: add required input variables for $folder
}

EOF
  done
}

if [[ -n "$WRITE_FILE" ]]; then
  generate > "$WRITE_FILE"
  echo "Generated module blocks in: $WRITE_FILE"
else
  generate
fi
