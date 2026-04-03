#!/usr/bin/env bash
set -euo pipefail

# update_module_sources.sh
# Rewrites module "source" in root/main.tf to:
#   source  = "gitlab.com/<namespace>/<registry-name>/aws//<module-folder>"
# and ensures:
#   version = "<version>"
#
# Usage:
#   ./update_module_sources.sh <root_main_tf> <namespace> <registry_name> <version>
#
# Example:
#   ./update_module_sources.sh ./root/main.tf arsalanshaikh13 ecr-three-tier-tf-modules 0.0.1

ROOT_MAIN_TF="${1:-}"
NAMESPACE="${2:-arsalanshaikh13}"
REGISTRY_NAME="${3:-ecr-three-tier-tf-modules}"
VERSION="${4:-0.0.1}"

if [[ -z "$ROOT_MAIN_TF" || -z "$NAMESPACE" || -z "$REGISTRY_NAME" || -z "$VERSION" ]]; then
  echo "Usage: $0 <root_main_tf> <namespace> <registry_name> <version>"
  exit 1
fi

if [[ ! -f "$ROOT_MAIN_TF" ]]; then
  echo "Error: file not found: $ROOT_MAIN_TF"
  exit 1
fi

tmp="$(mktemp)"

awk -v ns="$NAMESPACE" -v reg="$REGISTRY_NAME" -v ver="$VERSION" '
function print_block(   i, line, mod, has_source, has_version, src_indent, in_source, printed_version) {
  has_source=0; has_version=0; in_source=0; printed_version=0; src_indent="  "; mod=""

  # find module name from first line: module "name" {
  if (match(block[1], /^[[:space:]]*module[[:space:]]+"([^"]+)"/, m)) {
    mod = m[1]
  }

  # pass 1: detect source/version and source indent
  for (i=1; i<=n; i++) {
    line = block[i]
    if (line ~ /^[[:space:]]*source[[:space:]]*=/) {
      has_source=1
      match(line, /^[[:space:]]*/)
      src_indent=substr(line, RSTART, RLENGTH)
    }
    if (line ~ /^[[:space:]]*version[[:space:]]*=/) {
      has_version=1
    }
  }

  # pass 2: print with rewritten source/version
  for (i=1; i<=n; i++) {
    line = block[i]

    if (line ~ /^[[:space:]]*source[[:space:]]*=/) {
      print src_indent "source  = \"gitlab.com/" ns "/" reg "/aws//" mod "\""
      print src_indent "version = \"" ver "\""
      printed_version=1
      in_source=1
      continue
    }

    # skip multi-line source continuation if present
    if (in_source && line !~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ && line !~ /^[[:space:]]*}[[:space:]]*$/) {
      continue
    } else {
      in_source=0
    }

    # skip existing version line(s), since we already print version after source
    if (line ~ /^[[:space:]]*version[[:space:]]*=/) {
      continue
    }

    # before closing brace, add missing source/version
    if (line ~ /^[[:space:]]*}[[:space:]]*$/) {
      if (!has_source && mod != "") {
        print "  source  = \"gitlab.com/" ns "/" reg "/aws//" mod "\""
        print "  version = \"" ver "\""
        printed_version=1
      } else if (!printed_version) {
        print src_indent "version = \"" ver "\""
      }
    }

    print line
  }

  # reset block
  n=0
}

{
  if (!in_module && $0 ~ /^[[:space:]]*module[[:space:]]+"[^"]+"[[:space:]]*\{[[:space:]]*$/) {
    in_module=1
    n=0
    block[++n]=$0
    next
  }

  if (in_module) {
    block[++n]=$0
    if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
      print_block()
      in_module=0
    }
    next
  }

  print
}

END {
  if (in_module && n>0) {
    print_block()
  }
}
' "$ROOT_MAIN_TF" > "$tmp"

mv "$tmp" "$ROOT_MAIN_TF"
echo "Updated module source/version in: $ROOT_MAIN_TF"
