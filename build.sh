#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

IMAGES=(base vue3)

build_one() {
  local name=$1
  echo ">>> building cc-$name"
  docker build -t "cc-$name" "images/$name"
}

target="${1:-}"
for i in "${IMAGES[@]}"; do
  build_one "$i"
  [[ -n "$target" && "$i" == "$target" ]] && exit 0
done

if [[ -n "$target" ]]; then
  echo "unknown image: $target" >&2
  exit 1
fi
