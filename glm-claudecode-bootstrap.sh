#!/usr/bin/env bash

set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

has_command() {
  command -v "$1" >/dev/null 2>&1
}

run_local_or_remote_sh() {
  if [[ -f "$SCRIPT_DIR/glm-claudecode.sh" ]]; then
    exec bash "$SCRIPT_DIR/glm-claudecode.sh" "$@"
  fi

  if has_command curl; then
    curl -fsSL "$REPO_RAW_BASE/glm-claudecode.sh" | bash -s -- "$@"
    return
  fi

  if has_command wget; then
    wget -qO- "$REPO_RAW_BASE/glm-claudecode.sh" | bash -s -- "$@"
    return
  fi

  echo "❌ curl or wget is required to run bootstrap installer." >&2
  exit 1
}

run_local_or_remote_ps1() {
  local ps_cmd=""
  if has_command pwsh; then
    ps_cmd="pwsh"
  elif has_command powershell; then
    ps_cmd="powershell"
  else
    echo "❌ PowerShell is required for Windows bootstrap path." >&2
    exit 1
  fi

  if [[ -f "$SCRIPT_DIR/glm-claudecode.ps1" ]]; then
    exec "$ps_cmd" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/glm-claudecode.ps1" "$@"
  fi

  local tmp_ps1
  tmp_ps1="$(mktemp -t glm-claudecode.XXXXXX.ps1)"

  if has_command curl; then
    curl -fsSL "$REPO_RAW_BASE/glm-claudecode.ps1" -o "$tmp_ps1"
  elif has_command wget; then
    wget -qO "$tmp_ps1" "$REPO_RAW_BASE/glm-claudecode.ps1"
  else
    echo "❌ curl or wget is required to run bootstrap installer." >&2
    exit 1
  fi

  "$ps_cmd" -NoProfile -ExecutionPolicy Bypass -File "$tmp_ps1" "$@"
  rm -f "$tmp_ps1"
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    run_local_or_remote_ps1 "$@"
    ;;
  *)
    run_local_or_remote_sh "$@"
    ;;
esac
