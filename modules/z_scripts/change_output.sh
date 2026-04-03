#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./rename_tf_outputs.sh <root_dir>
# Example:
#   ./rename_tf_outputs.sh ./terraform_modules/ecr-three-tier-modules/modules

ROOT_DIR="${1:-.}"

derive_name() {
  local expr="$1"
  expr="${expr//[[:space:]]/}"
  expr="${expr#\$\{}"
  expr="${expr%\}}"

  # only simple refs like aws_lb.frontend_alb.zone_id
  [[ "$expr" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]] || return 1

  # drop first token (e.g., aws_lb), replace dots with underscores
  expr="${expr#*.}"
  echo "${expr//./_}"
}

process_file() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  awk '
    function derive(expr,   n, a, i, out) {
      gsub(/[[:space:]]/, "", expr)
      sub(/^\$\{/, "", expr)
      sub(/\}$/, "", expr)

      if (expr !~ /^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$/) return ""

      n = split(expr, a, ".")
      out = a[2]
      for (i = 3; i <= n; i++) out = out "_" a[i]
      return out
    }

    function flush_block(   i) {
      if (new_name != "") {
        sub(/output[[:space:]]+"[^"]+"/, "output \"" new_name "\"", block[1])
      }
      for (i = 1; i <= bcount; i++) print block[i]
      bcount = 0
      in_block = 0
      new_name = ""
    }

    {
      line = $0

      if (!in_block && line ~ /^[[:space:]]*output[[:space:]]+"[^"]+"[[:space:]]*\{[[:space:]]*$/) {
        in_block = 1
        bcount = 0
        new_name = ""
        block[++bcount] = line
        next
      }

      if (in_block) {
        block[++bcount] = line

        if (line ~ /^[[:space:]]*value[[:space:]]*=/) {
          expr = line
          sub(/^[[:space:]]*value[[:space:]]*=[[:space:]]*/, "", expr)
          sub(/[[:space:]]*#.*/, "", expr)   # remove inline comment
          candidate = derive(expr)
          if (candidate != "") new_name = candidate
        }

        if (line ~ /^[[:space:]]*\}[[:space:]]*$/) {
          flush_block()
        }
        next
      }

      print line
    }

    END {
      if (in_block) flush_block()
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
  echo "updated: $file"
}

export -f derive_name process_file

find "$ROOT_DIR" -type f -name "outputs.tf" | while read -r f; do
  process_file "$f"
done
