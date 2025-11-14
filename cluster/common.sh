#!/usr/bin/env bash

# ============================================================================
# COLOURS & FORMATTING
# ============================================================================

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
NC="\033[0m"
BOLD="\033[1m"

# ============================================================================
# FORMATTING FUNCTIONS
# ============================================================================

section() {
  printf "\n${BOLD}${BLUE}==> %s${NC}\n\n" "$1"
}

subsection() {
  printf "${BOLD}%s${NC}\n\n" "$1"
}

info()  { printf "  ${BLUE}➜${NC} %s\n" " $1"; }
ok()    { printf "  ${GREEN}✔${NC} %s\n" " $1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" " $1"; }
error() { printf "  ${RED}✖${NC} %s\n" " $1"; }

# ============================================================================
# SPINNER & STEP EXECUTION LOGIC
# ============================================================================

SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

spinner() {
  local msg="$1"
  local pid="$2"
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${BLUE}%s${NC}  %s..." "${SPINNER_FRAMES[$i]}" "$msg"
    i=$(( (i + 1) % ${#SPINNER_FRAMES[@]} ))
    sleep 0.1
  done
}

run_step() {
  local msg="$1"
  shift

  # Run command in background
  "$@" >/tmp/null 2>&1 &
  local cmd_pid=$!

  # Start spinner linked to command pid
  spinner "$msg" "$cmd_pid" &
  local spinner_pid=$!

  # Wait for main command to finish
  wait "$cmd_pid"
  local status=$?

  # Stop spinner safely
  if kill -0 "$spinner_pid" 2>/dev/null; then
    kill -TERM "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
  fi

  # Print final result
  if [ "$status" -eq 0 ]; then
    printf "\r  ${GREEN}✔${NC}  %s\n" "$msg"
  else
    printf "\r  ${RED}✖${NC}  %s\n" "$msg"
  fi

  return "$status"
}
