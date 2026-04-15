#!/usr/bin/env bash
set -euo pipefail

DOCS_DIR="docs"

mkdir -p "$DOCS_DIR"
echo "moving md files to docs"
find . \
  -type f \
  -name "*.md" \
  ! -path "./$DOCS_DIR/*" \
  -print0 |
while IFS= read -r -d '' file; do
  target="$DOCS_DIR/$(basename "$file")"

  if [ -e "$target" ]; then
    echo "Skipping $file -> $target (target already exists)"
    continue
  fi

  echo "Moving $file -> $target"
  mv -v "$file" "$target"
done
