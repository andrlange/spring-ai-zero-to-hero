#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ollama.sh — Export / Import Ollama models used by this workshop
#
# GGUF model files are architecture- and OS-independent.
# A model exported on arm64 macOS works on amd64 Linux and vice versa.
#
# Run without arguments for interactive menu, or pass a command directly:
#   ./ollama.sh export              # → models.tar.gz  (all workshop models)
#   ./ollama.sh export model1 ...   # → models.tar.gz  (selected models only)
#   ./ollama.sh import              # ← models.tar.gz  (restore into Ollama)
#   ./ollama.sh pull                # pull all workshop models from registry
#   ./ollama.sh list                # show which workshop models are installed
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="${SCRIPT_DIR}/models.tar.gz"

# Models used by this workshop (edit as needed)
WORKSHOP_MODELS=(
  "mistral"
  "nomic-embed-text"
  "llama3.2"
  "llava"
)

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

# Locate the Ollama models directory
find_models_dir() {
  if [[ -n "${OLLAMA_MODELS:-}" ]]; then
    echo "$OLLAMA_MODELS"
  elif [[ -d "$HOME/.ollama/models" ]]; then
    echo "$HOME/.ollama/models"
  elif [[ -d "/usr/share/ollama/.ollama/models" ]]; then
    echo "/usr/share/ollama/.ollama/models"
  else
    echo -e "${RED}ERROR: Cannot find Ollama models directory.${RESET}" >&2
    echo "Set OLLAMA_MODELS or ensure ~/.ollama/models exists." >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# EXPORT — pack model blobs + manifests into a portable tar.gz
# ---------------------------------------------------------------------------
do_export() {
  local models_dir
  models_dir="$(find_models_dir)" || return 1
  echo -e "${DIM}Ollama models directory: $models_dir${RESET}"

  # Determine which models to export
  local targets=()
  if [[ $# -gt 0 ]]; then
    targets=("$@")
  else
    targets=("${WORKSHOP_MODELS[@]}")
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  mkdir -p "$tmpdir/manifests" "$tmpdir/blobs"

  local exported=0
  for model in "${targets[@]}"; do
    local name="${model%%:*}"
    local tag="${model#*:}"
    [[ "$tag" == "$name" ]] && tag="latest"

    local manifest_dir="$models_dir/manifests/registry.ollama.ai/library/$name"
    local manifest_file="$manifest_dir/$tag"

    if [[ ! -f "$manifest_file" ]]; then
      echo -e "  ${YELLOW}SKIP${RESET}  $name:$tag (not installed)"
      continue
    fi

    echo -e "  ${GREEN}EXPORT${RESET} $name:$tag"

    # Copy manifest
    local dest_manifest_dir="$tmpdir/manifests/registry.ollama.ai/library/$name"
    mkdir -p "$dest_manifest_dir"
    cp "$manifest_file" "$dest_manifest_dir/$tag"

    # Copy referenced blobs
    local digests
    digests=$(grep -oE 'sha256:[a-f0-9]+' "$manifest_file" | sort -u)
    for digest in $digests; do
      local blob_file="$models_dir/blobs/${digest//:/-}"
      if [[ -f "$blob_file" ]]; then
        cp -n "$blob_file" "$tmpdir/blobs/" 2>/dev/null || true
      else
        echo -e "  ${YELLOW}WARN${RESET}  blob not found: $digest"
      fi
    done

    exported=$((exported + 1))
  done

  if [[ $exported -eq 0 ]]; then
    echo -e "${RED}No models found to export.${RESET} Pull them first with option [3]."
    rm -rf "$tmpdir"
    trap - EXIT
    return 1
  fi

  echo ""
  echo "Packing $exported model(s) into $ARCHIVE ..."
  tar -czf "$ARCHIVE" -C "$tmpdir" manifests blobs
  rm -rf "$tmpdir"
  trap - EXIT

  local size
  size=$(du -h "$ARCHIVE" | cut -f1)
  echo -e "${GREEN}Done${RESET} — $ARCHIVE ($size)"
}

# ---------------------------------------------------------------------------
# IMPORT — unpack archive into the Ollama models directory
# ---------------------------------------------------------------------------
do_import() {
  local models_dir
  models_dir="$(find_models_dir)" || return 1

  if [[ ! -f "$ARCHIVE" ]]; then
    echo -e "${RED}ERROR: $ARCHIVE not found.${RESET} Export models first with option [1]." >&2
    return 1
  fi

  echo "Importing models from $ARCHIVE into $models_dir ..."
  tar -xzf "$ARCHIVE" -C "$models_dir"

  echo -e "${GREEN}Done.${RESET} Restart Ollama if it was running, then verify with:"
  echo "  ollama list"
}

# ---------------------------------------------------------------------------
# PULL — download all workshop models from the Ollama registry
# ---------------------------------------------------------------------------
do_pull() {
  echo "Pulling workshop models ..."
  for model in "${WORKSHOP_MODELS[@]}"; do
    echo ""
    echo -e "--- ${CYAN}$model${RESET} ---"
    ollama pull "$model"
  done
  echo ""
  echo -e "${GREEN}All workshop models pulled.${RESET}"
}

# ---------------------------------------------------------------------------
# LIST — show which workshop models are installed locally
# ---------------------------------------------------------------------------
do_list() {
  echo ""
  echo -e "${BOLD}Workshop models:${RESET}"
  echo ""
  local installed
  installed="$(ollama list 2>/dev/null || true)"

  for model in "${WORKSHOP_MODELS[@]}"; do
    if echo "$installed" | grep -q "^${model}"; then
      echo -e "  ${GREEN}✓${RESET}  $model"
    else
      echo -e "  ${RED}✗${RESET}  $model  ${DIM}(not installed)${RESET}"
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
  echo -e "${BOLD}  Ollama Model Manager${RESET}"
  echo -e "${BOLD}  Spring AI Zero-to-Hero Workshop${RESET}"
  echo -e "${BOLD}========================================${RESET}"
  echo ""
  echo -e "  ${CYAN}1${RESET})  Export models to models.tar.gz"
  echo -e "  ${CYAN}2${RESET})  Import models from models.tar.gz"
  echo -e "  ${CYAN}3${RESET})  Pull all workshop models"
  echo -e "  ${CYAN}4${RESET})  List installed workshop models"
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
    export) shift; do_export "$@" ;;
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
