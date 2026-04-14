#!/usr/bin/env bash
# build.sh — Build cc-* Docker images in dependency order.
#
# Usage:
#   ./build.sh [IMAGE]
#
#   IMAGE  Short name of the target image (the part after "cc-").
#          Builds the target and all its transitive dependencies.
#          Omit to build every discovered image.
#
# Images are discovered from images/*/Dockerfile. Dependencies are inferred
# from FROM cc-<name> and COPY --from=cc-<name> directives in each Dockerfile.
# A topological sort ensures dependencies are always built before their
# dependents. Circular dependencies are detected and reported as errors.
#
# Examples:
#   ./build.sh           # build all images
#   ./build.sh vue3      # build cc-vue3 and its dependencies only
set -euo pipefail
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# Discover all images: any subdirectory of images/ that contains a Dockerfile
# ---------------------------------------------------------------------------
declare -A DEPS  # DEPS[name]="dep1 dep2 ..."

discover_images() {
  for dockerfile in images/*/Dockerfile; do
    [[ -f "$dockerfile" ]] || continue
    local name
    name=$(basename "$(dirname "$dockerfile")")
    DEPS["$name"]=""
  done
}

# ---------------------------------------------------------------------------
# Build dependency graph by scanning each Dockerfile for local cc-* references:
#   FROM cc-<name> [AS alias]
#   COPY --from=cc-<name> ...
# ---------------------------------------------------------------------------
build_graph() {
  for name in "${!DEPS[@]}"; do
    local dockerfile="images/$name/Dockerfile"
    local seen_deps=""
    while IFS= read -r dep; do
      # dep is the short name after "cc-"
      [[ "$dep" == "$name" ]] && continue           # skip self-reference
      [[ -v DEPS["$dep"] ]] || continue             # skip unknown images
      # deduplicate
      case " $seen_deps " in
        *" $dep "*) continue ;;
      esac
      seen_deps="$seen_deps $dep"
    done < <(
      grep -Eo '(FROM[[:space:]]+cc-[^[:space:]]+|--from=cc-[^[:space:]]+)' "$dockerfile" 2>/dev/null \
        | sed -E 's/^(FROM[[:space:]]+cc-|--from=cc-)//' \
        | sed -E 's/[[:space:]]+AS[[:space:]]+.*//'
    )
    DEPS["$name"]="${seen_deps# }"
  done
}

# ---------------------------------------------------------------------------
# Topological sort (DFS post-order → reverse = topo order)
# Sets TOPO_ORDER array.
# ---------------------------------------------------------------------------
declare -A VISITED  # 0=unvisited, 1=in-progress, 2=done
TOPO_ORDER=()

topo_visit() {
  local node=$1
  local state="${VISITED[$node]:-0}"
  if [[ "$state" == "2" ]]; then return; fi
  if [[ "$state" == "1" ]]; then
    echo "error: dependency cycle detected involving image: $node" >&2
    exit 1
  fi
  VISITED["$node"]=1
  for dep in ${DEPS[$node]:-}; do
    topo_visit "$dep"
  done
  VISITED["$node"]=2
  TOPO_ORDER+=("$node")
}

topo_sort() {
  for name in "${!DEPS[@]}"; do
    topo_visit "$name"
  done
}

# ---------------------------------------------------------------------------
# Compute transitive dependency closure of a target (including itself)
# Result stored in CLOSURE associative array.
# ---------------------------------------------------------------------------
declare -A CLOSURE

closure_visit() {
  local node=$1
  [[ -v CLOSURE["$node"] ]] && return
  CLOSURE["$node"]=1
  for dep in ${DEPS[$node]:-}; do
    closure_visit "$dep"
  done
}

# ---------------------------------------------------------------------------
# Build one image
# ---------------------------------------------------------------------------
build_one() {
  local name=$1
  echo ">>> building cc-$name"
  docker build -t "cc-$name" "images/$name"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
discover_images
build_graph
topo_sort

target="${1:-}"

if [[ -n "$target" ]]; then
  if [[ ! -v DEPS["$target"] ]]; then
    echo "unknown image: $target" >&2
    exit 1
  fi
  closure_visit "$target"
  for name in "${TOPO_ORDER[@]}"; do
    if [[ -v CLOSURE["$name"] ]]; then
      build_one "$name"
    fi
  done
else
  for name in "${TOPO_ORDER[@]}"; do
    build_one "$name"
  done
fi
