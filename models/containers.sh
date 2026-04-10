#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# containers.sh — Export / Import Docker images used by this workshop
#
# Pre-download Docker images so attendees don't need to pull them
# during the workshop when internet may be slow.
#
# Run without arguments for interactive menu, or pass a command directly:
#   ./containers.sh export     # → containers.tar.gz  (all workshop images)
#   ./containers.sh import     # ← containers.tar.gz  (load into Docker)
#   ./containers.sh pull       # pull all workshop images from registry
#   ./containers.sh list       # show which workshop images are available locally
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="${SCRIPT_DIR}/containers.tar.gz"

# Docker images used by this workshop (edit as needed)
# Source: docker/postgres/docker-compose.yaml
#         docker/observability-stack/docker-compose.yaml
WORKSHOP_IMAGES=(
  "pgvector/pgvector:pg18"
  "dpage/pgadmin4:latest"
  "grafana/otel-lgtm:latest"
  "maildev/maildev:2.2.1"
)

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# Check that Docker is available and running
check_docker() {
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}ERROR: Docker is not installed.${RESET}" >&2
    return 1
  fi
  if ! docker info &>/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker daemon is not running.${RESET}" >&2
    return 1
  fi
}

# Check if a Docker image exists locally
image_exists() {
  docker image inspect "$1" &>/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# EXPORT — save Docker images into a portable tar.gz
# ---------------------------------------------------------------------------
do_export() {
  check_docker || return 1

  local found_images=()
  for image in "${WORKSHOP_IMAGES[@]}"; do
    if image_exists "$image"; then
      echo -e "  ${GREEN}FOUND${RESET}   $image"
      found_images+=("$image")
    else
      echo -e "  ${YELLOW}SKIP${RESET}    $image (not pulled locally)"
    fi
  done

  if [[ ${#found_images[@]} -eq 0 ]]; then
    echo -e "${RED}No images found to export.${RESET} Pull them first with option [3]."
    return 1
  fi

  echo ""
  echo "Saving ${#found_images[@]} image(s) into $ARCHIVE ..."
  docker save "${found_images[@]}" | gzip > "$ARCHIVE"

  local size
  size=$(du -h "$ARCHIVE" | cut -f1)
  echo -e "${GREEN}Done${RESET} — $ARCHIVE ($size)"
}

# ---------------------------------------------------------------------------
# IMPORT — load Docker images from archive
# ---------------------------------------------------------------------------
do_import() {
  check_docker || return 1

  if [[ ! -f "$ARCHIVE" ]]; then
    echo -e "${RED}ERROR: $ARCHIVE not found.${RESET} Export images first with option [1]." >&2
    return 1
  fi

  local size
  size=$(du -h "$ARCHIVE" | cut -f1)
  echo "Loading images from $ARCHIVE ($size) ..."
  gunzip -c "$ARCHIVE" | docker load

  echo ""
  echo -e "${GREEN}Done.${RESET} Verify with:"
  echo "  docker images"
}

# ---------------------------------------------------------------------------
# PULL — download all workshop images from Docker Hub
# ---------------------------------------------------------------------------
do_pull() {
  check_docker || return 1

  echo "Pulling workshop images ..."
  for image in "${WORKSHOP_IMAGES[@]}"; do
    echo ""
    echo -e "--- ${CYAN}$image${RESET} ---"
    docker pull "$image"
  done
  echo ""
  echo -e "${GREEN}All workshop images pulled.${RESET}"
}

# ---------------------------------------------------------------------------
# LIST — show which workshop images are available locally
# ---------------------------------------------------------------------------
do_list() {
  check_docker || return 1

  echo ""
  echo -e "${BOLD}Workshop Docker images:${RESET}"
  echo ""
  for image in "${WORKSHOP_IMAGES[@]}"; do
    if image_exists "$image"; then
      local size
      size=$(docker image inspect "$image" --format='{{.Size}}' 2>/dev/null)
      # Convert bytes to human-readable (awk works on both macOS and Linux)
      local human_size
      human_size=$(echo "$size" | awk '{
        if ($1 >= 1073741824) printf "%.1f GiB", $1/1073741824
        else if ($1 >= 1048576) printf "%.0f MiB", $1/1048576
        else if ($1 >= 1024) printf "%.0f KiB", $1/1024
        else printf "%d B", $1
      }' 2>/dev/null || echo "${size} bytes")
      echo -e "  ${GREEN}✓${RESET}  $image  ${DIM}($human_size)${RESET}"
    else
      echo -e "  ${RED}✗${RESET}  $image  ${DIM}(not pulled)${RESET}"
    fi
  done
  echo ""
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
show_menu() {
  echo ""
  echo -e "${BOLD}========================================${RESET}"
  echo -e "${BOLD}  Docker Image Manager${RESET}"
  echo -e "${BOLD}  Spring AI Zero-to-Hero Workshop${RESET}"
  echo -e "${BOLD}========================================${RESET}"
  echo ""
  echo -e "  ${CYAN}1${RESET})  Export images to containers.tar.gz"
  echo -e "  ${CYAN}2${RESET})  Import images from containers.tar.gz"
  echo -e "  ${CYAN}3${RESET})  Pull all workshop images"
  echo -e "  ${CYAN}4${RESET})  List local workshop images"
  echo ""
  echo -e "  ${DIM}q)  Quit${RESET}"
  echo ""
}

interactive() {
  while true; do
    show_menu
    read -rp "Choose [1-4, q]: " choice
    echo ""
    case "$choice" in
      1) do_export ;;
      2) do_import ;;
      3) do_pull ;;
      4) do_list ;;
      q|Q) echo "Bye."; exit 0 ;;
      *) echo -e "${YELLOW}Invalid choice.${RESET} Enter 1-4 or q." ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Main — interactive if no arguments, otherwise direct command
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  interactive
else
  case "$1" in
    export) do_export ;;
    import) do_import ;;
    pull)   do_pull ;;
    list)   do_list ;;
    *)
      echo "Usage: $0 [export|import|pull|list]"
      echo ""
      echo "Run without arguments for interactive menu."
      exit 1
      ;;
  esac
fi
