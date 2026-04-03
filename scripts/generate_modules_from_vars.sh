#!/usr/bin/env bash
set -euo pipefail

# generate_modules_from_vars.sh
# Run from: ecr-three-tier-modules/
#
# What it does:
# 1) Scans each immediate subfolder under ./modules
# 2) Reads variables.tf and extracts: variable "name"
# 3) Generates module blocks in generated.tf
# 4) For each extracted variable, writes: name = var.name
#
# Usage:
#   ./generate_modules_from_vars.sh
#   ./generate_modules_from_vars.sh modules generated.tf

MODULES_DIR="${1:-modules}"
OUT_FILE="${2:-generated.tf}"

if [[ ! -d "$MODULES_DIR" ]]; then
  echo "Error: modules dir not found: $MODULES_DIR" >&2
  exit 1
fi

# start fresh
: > "$OUT_FILE"

# loop subfolders under modules/
find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r mod_path; do
  folder="$(basename "$mod_path")"
  vars_file="$mod_path/variables.tf"

  # terraform module labels cannot contain '-'
  module_label="$(echo "$folder" | sed 's/[^A-Za-z0-9_]/_/g')"

  {
    echo "module \"$module_label\" {"
    echo "  source = \"../modules/$folder\""
    echo ""

    if [[ -f "$vars_file" ]]; then
      # extract: variable "some_name"
      mapfile -t vars < <(
        grep -E '^[[:space:]]*variable[[:space:]]+"[A-Za-z_][A-Za-z0-9_]*"' "$vars_file" \
        | sed -E 's/^[[:space:]]*variable[[:space:]]+"([^"]+)".*/\1/' \
        | sort -u
      )

      for v in "${vars[@]}"; do
        echo "  $v = var.$v"
      done
    else
      echo "  # No variables.tf found in $folder"
    fi

    echo "}"
    echo ""
  } >> "$OUT_FILE"
done

echo "Generated module blocks in: $OUT_FILE"
