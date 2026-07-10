#!/bin/zsh
# Ollama Model Updater
# Updates all installed Ollama models to their latest versions
# Provides colored output with status indicators and summary statistics

set -u -o pipefail

# Command-line option defaults
show_unchanged=1  # Show models that didn't require updating
no_color="${NO_COLOR:-}"  # Respect NO_COLOR environment variable

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quiet) show_unchanged=0 ;;  # Suppress "already current" messages
    --no-color) no_color=1 ;;  # Disable ANSI color codes
    -h|--help)
      cat <<'USAGE'
Usage: ollama_update_models.sh [-q|--quiet] [--no-color]
  -q, --quiet    Hide "OK (already current)" lines
  --no-color     Disable colored output
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done


# Initialize color support (auto-detect if terminal supports colors)
enable_color=0
if [[ -t 1 && -z "$no_color" ]]; then
  if command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    enable_color=1
  fi
fi

# Define color codes and reset sequence (empty strings if colors disabled)
if (( enable_color )); then
  C_RESET="$(tput sgr0)"      # Reset to default
  C_DIM="$(tput dim 2>/dev/null || printf '')"   # Dim text
  C_OK="$(tput setaf 2)"      # Green
  C_UPD="$(tput setaf 4)"     # Blue
  C_SKP="$(tput setaf 3)"     # Yellow
  C_FAIL="$(tput setaf 1)"    # Red
else
  C_RESET=""; C_DIM=""; C_OK=""; C_UPD=""; C_SKP=""; C_FAIL=""
fi

# Status icons for output
ICON_OK="✓"
ICON_UPD="⬆"
ICON_SKP="⏭"
ICON_FAIL="✖"


# Print a formatted status line with color, icon, and message
# Args: $1=color_code, $2=icon, $3=status_label, $4=model_name, $5=optional_details
print_status() {
  printf "%b%s%b  %-8s %s%s\n" "$1" "$2" "$C_RESET" "$3" "$4" "${5:-}"
}

# Extract first 12 characters of model ID for display, or "-" if empty
# Args: $1=model_id
short_id() {
  local id="${1:-}"
  [[ -n "$id" ]] && printf '%.12s' "$id" || printf "-"
}

# List of models to skip during updates (add model names here to exclude them)
skip_models=(
  "example-model:latest"
) 

# Check if a model name is in the skip list
# Args: $1=model_name
# Returns: 0 if in skip list, 1 otherwise
in_skip_list() {
  local n="$1"
  local s
  for s in "${skip_models[@]}"; do
    [[ "$s" == "$n" ]] && return 0
  done
  return 1
}


# Verify Ollama is installed and daemon is running
if ! command -v ollama >/dev/null 2>&1; then
  echo "Error: Ollama is not installed or not in PATH"
  exit 1
fi

if ! models="$(ollama list 2>/dev/null)"; then
  echo "Error: Cannot connect to the Ollama daemon."
  echo "Start it and retry."
  exit 1
fi

# Extract model names (first column, skip header)
names_only="$(printf '%s\n' "$models" | awk 'NR>1{print $1}')"

if [[ -z "$names_only" ]]; then
  echo "No models installed yet."
  echo "Tip: pull one with e.g. 'ollama pull llama3.2:latest'"
  exit 0
fi

# Build associative array mapping model names to their current IDs
typeset -A id_before_map

while IFS=$' \t' read -r name id rest; do
  [[ -z "$name" || "$name" == "NAME" ]] && continue
  id_before_map[$name]="$id"
done <<< "$models"

# Initialize counters and arrays for tracking results
updated_count=0
unchanged_count=0
failed_count=0
skipped_count=0
daemon_aborted=0

typeset -a updated_models
typeset -a unchanged_models
typeset -a failed_models
typeset -a skipped_model_names

# Helper function to fetch current model ID from Ollama
# Args: $1=model_name
get_model_id() {
  ollama list 2>/dev/null | awk -v m="$1" '$1==m{print $2; exit}'
}


# Main loop: iterate through each installed model and attempt to update
while IFS= read -r model; do
  [[ -z "$model" ]] && continue

  # Check if model is in skip list
  if in_skip_list "$model"; then
    skipped_model_names+=("$model")
    ((skipped_count++))
    print_status "$C_SKP" "$ICON_SKP" "SKIP" "$model"
    continue
  fi

  id_before="${id_before_map[$model]:-}"

  # Attempt to pull (update) the model
  if output="$(ollama pull "$model" 2>&1)"; then
    id_after="$(get_model_id "$model")"

    # Check if model ID changed (indicating an update)
    if [[ -n "$id_before" && -n "$id_after" && "$id_after" == "$id_before" ]]; then
      # Model unchanged - already at latest version
      unchanged_models+=("$model")
      ((unchanged_count++))
      (( show_unchanged )) && print_status "$C_OK" "$ICON_OK" "OK" "$model" " ${C_DIM}(already current)${C_RESET}"
    else
      # Model was updated or is new
      updated_models+=("$model")
      ((updated_count++))

      before_short="$(short_id "$id_before")"
      after_short="$(short_id "$id_after")"

      if [[ "$before_short" == "-" ]]; then
        print_status "$C_UPD" "$ICON_UPD" "UPDATED" "$model" " ${C_DIM}(new id ${after_short})${C_RESET}"
      else
        print_status "$C_UPD" "$ICON_UPD" "UPDATED" "$model" " ${C_DIM}(${before_short} → ${after_short})${C_RESET}"
      fi
    fi
  else
    # Update failed
    failed_models+=("$model")
    ((failed_count++))

    first_line="$(printf '%s\n' "$output" | sed -n '1p')"
    print_status "$C_FAIL" "$ICON_FAIL" "FAILED" "$model" " ${C_DIM}— ${first_line}${C_RESET}"

    # Check if daemon went down during update
    if grep -Ei 'server not responding|could not connect|connection refused|connection reset' <<< "$output" >/dev/null; then
      if ! ollama list >/dev/null 2>&1; then
        echo
        echo "Ollama daemon appears to be down; aborting remaining updates."
        daemon_aborted=1
        break
      fi
    fi
  fi
done <<< "$names_only"


# Calculate totals and print summary
total=$((updated_count + unchanged_count + failed_count + skipped_count))

echo
echo "=================================== Summary ==================================="
printf "Total: %d | %b%s%b %d | %b%s%b %d | %b%s%b %d | %b%s%b %d\n" \
  "$total" \
  "$C_SKP"  "⏭  Skipped:"   "$C_RESET" "$skipped_count" \
  "$C_UPD"  "⬆ Updated:"    "$C_RESET" "$updated_count" \
  "$C_OK"   "✓ No change:"  "$C_RESET" "$unchanged_count" \
  "$C_FAIL" "✖  Failed:"    "$C_RESET" "$failed_count"

(( daemon_aborted )) && echo "Note: Aborted early because the Ollama daemon stopped responding."

# Print detailed lists of each category
if (( skipped_count )); then
  echo -n "Skipped models: "
  printf '%s ' "${skipped_model_names[@]}"
  echo
fi

if (( updated_count )); then
  echo -n "Updated models: "
  printf '%s ' "${updated_models[@]}"
  echo
fi

if (( show_unchanged )) && (( unchanged_count )); then
  echo -n "No-change models: "
  printf '%s ' "${unchanged_models[@]}"
  echo
fi

if (( failed_count )); then
  echo -n "Failed models: "
  printf '%s ' "${failed_models[@]}"
  echo
  echo "Hint: If the daemon went down, run 'ollama serve' and rerun this script."
fi

# Exit with status code reflecting success/failure
(( failed_count > 0 )) && exit 1 || exit 0
